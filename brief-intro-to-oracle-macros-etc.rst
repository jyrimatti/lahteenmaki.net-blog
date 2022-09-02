A brief intro to Oracle macros etc
==================================

:Abstract: Some basics of Pipelined Table Functions, Polymorphic Table Functions and Macros in Oracle
:Authors: Jyri-Matti Lähteenmäki
:Date: 2022-09-02
:Status: Published


Relational databases and particularly SQL (Structured Query Language) have proven to be a great tool for solving a lot of problems. Despite being decades old and continuously facing a challenge from various NoSQL products, they are still gaining more and more features. Here follows a small introduction from basics to macros in `Oracle database<https://www.oracle.com/database/>`__.



Views: the most useful abstraction
----------------------------------

SQL is mostly about manipulating and transforming *relations* into different forms. A relation, however, doesn't need to be a fixed *table*. *Queries* are also relations, kind of *dynamic* relations. A *view* is also a relation, a kind of a *saved query*.

Let's look at a simple table:

.. code:: sql

    CREATE TABLE foo (
        col1 NUMBER,
        col2 VARCHAR2(8)
    );
    INSERT INTO foo VALUES (1, 'hello');

If we perform a simple ``select``, we get all the rows, as expected:

.. code:: sql

    SELECT * FROM foo;
    -- 1 hello

We can save reusable queries as views, as a simple and ubiquitous way to build abstractions. Like queries, views don't need to be straightforward transformations of a table or two. They may sometimes contain almost arbitrarily complex logic:

.. code:: sql

    CREATE OR REPLACE VIEW foobar AS
    SELECT col1, val
    FROM foo,
        (SELECT 0 val FROM DUAL UNION ALL SELECT 1 FROM DUAL);

    SELECT * FROM foobar;
    -- 1 0
    -- 1 1

However, it quickly becomes apparent that complex logic isn't that easy to implement in pure SQL. Also, while a query can be parameterized with bind variables, views (in general) can't, although it can somewhat be faked with optimizer features like `predicate pushdown<https://blogs.oracle.com/optimizer/post/optimizer-transformation-join-predicate-pushdown>`__ or database-specific features like `session contexts<https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SYS_CONTEXT.html>`__.

Still, I would argue, views are the most important abstraction in relational databases. But what if we need more?



PL/SQL: programming in the deep end
-----------------------------------

Jumping straight to the deep end is rarely desirable, but at least it's an option. Different database vendors provide different support for programming (in something else than SQL). Oracle has a programming language called `PL/SQL<https://en.wikipedia.org/wiki/PL/SQL>`__.

Combining PL/SQL with *functions*, we can use almost arbitrary programming to produce a table dynamically:

.. code:: sql

    -- a type for "a table of strings"
    CREATE OR REPLACE TYPE StringTable AS TABLE OF VARCHAR2(32000);
    /

    -- a function returning a table
    CREATE OR REPLACE FUNCTION helloworld RETURN StringTable AS
        hello VARCHAR2(64);
    BEGIN
        SELECT col2 INTO hello FROM foo FETCH FIRST ROW ONLY;
        RETURN StringTable(hello||' world');
    END;
    /

    SELECT helloworld FROM DUAL;
    -- STRINGTABLE('hello world')

    SELECT * FROM table(helloworld);
    -- hello world

This allows us to create a table on the fly, with arbitrary business logic, utilizing both PL/SQL and pure SQL as needed. Raw performance can be great since we can program at a really low level, compared to pure SQL which could be described as one of the highest-level languages in the world. The resulting table can be directly used from SQL making functions a natural tool in the toolbox.

However, there are some downsides.

First of all, if you've been programming with various languages and libraries, you'll quickly notice that PL/SQL isn't exactly the most pleasant thing to work with. It's also quite far apart from SQL (unless you happen to use mostly SQL within PL/SQL), which is, after all, the language you want to be using most of the time when interacting with a relational database.

Second, the table returned from the function is constructed and returned as a whole. This won't matter if it's small but might be problematic if it's large. In addition, the caller might only need the first few rows but the whole table will still be produced.

Performance *can* be great, but it's a bit more nuanced than that. At least in Oracle, SQL and PL/SQL code are executed in different *runtimes*. If you happen to be a mobile developer, think about `React Native<https://reactnative.dev>`__ inside iPhone, which is constantly jumping between iOS runtime and JavaScript runtime. A Java developer might think about jumping from JVM to a native C implementation and back.

Each context switch from one runtime to the other brings a (small) performance overhead. Although measured more or less in microseconds, when executed a million times or accompanied with lots of data (like a big table) to copy from one runtime to another, the overhead starts to show.

Especially if you are performing lots of SQL queries inside your PL/SQL blocks, the result is going to be executing several *different* queries each *optimized* as separate queries. Oracle can't optimize PL/SQL blocks to run as part of SQL queries (or vice versa) in general. Optimizations like `PRAGMA UDF or functions in WITH clause<https://oracle.readthedocs.io/en/latest/plsql/cache/udf-pragma.html>`__ may improve performance, but you shouldn't count on it.

Could there possibly be some useful middle ground between these far ends?



Pipelined Table Functions
-------------------------

`Pipelined Table functions<https://docs.oracle.com/en/database/oracle/oracle-database/19/addci/using-pipelined-and-parallel-table-functions.html#GUID-EFB94CFB-3E44-4236-B490-ADBB480C94D4>`__ are like ordinary functions returning tables, but they are lazy: the table is constructed and returned row-by-row. Or maybe more accurately, as many rows at a time as the database engine sees fit.

.. code:: sql

    -- a type for "a table of numbers"
    CREATE OR REPLACE TYPE NumberTable AS TABLE OF NUMBER;
    /

    CREATE OR REPLACE FUNCTION fib RETURN NumberTable PIPELINED AS
        v1 NUMBER := 0;
        v2 NUMBER := 1;
    BEGIN
        LOOP
            PIPE ROW (v1);
            v2 := v1 + v2;
            v1 := v2 - v1;
        END LOOP;
    END;
    /

    SELECT * FROM table(fib);
    -- 0
    -- 1
    -- 1
    -- 2
    -- 3
    -- 5
    -- ...

I'm sure you could generate a `Fibonacci sequence<https://en.wikipedia.org/wiki/Fibonacci_number>`__ with pure SQL, but for many things, SQL simply becomes too complex. In this example, the function signature has an added ``PIPELINED`` keyword, and the body outputs rows one at a time. If you happen to have experience in `Python generators<https://wiki.python.org/moin/Generators>`__ or other `coroutines<https://lahteenmaki.net/dev_*21/>`__, this might look somewhat familiar.

There is no context switching inside the function body since it's pure PL/SQL, but the execution is still jumping between the SQL consumer and the PL/SQL producer. Anyway, producing rows one at a time will bring a huge performance benefit in some use cases compared to the previous example.

But if you now go and start implementing a bunch of common library functions utilizing pipelined table functions, you'll quickly notice a problem. The return type can't depend on the parameters for the function. It has to be statically defined. Therefore you cannot implement a function like ``take(n NUMBER, tablename VARCHAR2)`` which would return first ``n`` rows from a table, unless you satisfy with returning weakly typed (and thus difficult to utilize) ``SYS_REFCURSOR``s. This severely limits the kind of abstractions you can create.



Polymorphic Table Functions
---------------------------

`Polymorphic Table Functions<https://oracle-base.com/articles/18c/polymorphic-table-functions-18c>`__ fill the niche described in the previous section. They also are functions producing tables, but this time a mechanism is provided to describe the returned structure strongly and dynamically, and based on input parameters.

For these we need to specify an implementation package:

.. code:: sql

    CREATE OR REPLACE PACKAGE ptf AS
        -- tells the structure of the returned table
        FUNCTION describe(sometable IN OUT DBMS_TF.TABLE_T,
                          keepcols IN DBMS_TF.COLUMNS_T DEFAULT NULL,
                          invert IN NUMBER DEFAULT 0,
                          clearcontent IN NUMBER DEFAULT 0) RETURN DBMS_TF.DESCRIBE_T;
        
        -- produces the returned rows. Same params except for DBMS_TF types.
        PROCEDURE fetch_rows(invert IN NUMBER DEFAULT 0, clearcontent IN NUMBER DEFAULT 0);
        
        -- entrypoint. No implementation. Same params, but slightly different types.
        FUNCTION my_ptf(sometable IN OUT TABLE,
                        keepcols IN COLUMNS DEFAULT NULL,
                        invert IN NUMBER DEFAULT NULL,
                        clearcontent IN NUMBER DEFAULT 0) RETURN TABLE PIPELINED ROW POLYMORPHIC USING ptf;
    END;
    /

The implementation looks already a bit involved, and you might want to consult the `documentation of DBMS_TF package<https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_TF.html#GUID-E8D0433C-7442-4909-87EF-217ECB278312>`__. A nice feature is that you only need to take into account the parts you care for, for example, fetch_rows can be left out if you only need to modify the structure.

.. code:: sql

    CREATE OR REPLACE PACKAGE BODY ptf AS
        FUNCTION describe(sometable IN OUT DBMS_TF.TABLE_T,
                          keepcols IN DBMS_TF.COLUMNS_T DEFAULT NULL,
                          invert IN NUMBER DEFAULT 0,
                          clearcontent IN NUMBER DEFAULT 0) RETURN DBMS_TF.DESCRIBE_T IS
            bool BOOLEAN := CASE invert WHEN 0 THEN false ELSE true END;
        BEGIN
            FOR i IN 1..sometable.COLUMN.COUNT LOOP  
                IF keepcols IS NOT EMPTY AND sometable.column(i).description.name NOT MEMBER OF keepcols THEN
                    sometable.column(i).pass_through := bool;
                    sometable.column(i).for_read     := bool;
                ELSE
                    sometable.column(i).pass_through := NOT bool;
                    sometable.column(i).for_read     := NOT bool;
                END IF;
            END LOOP;
            
            IF clearcontent <> 0 THEN
                RETURN DBMS_TF.DESCRIBE_T(row_replication => true);
            ELSE
                -- could return an arbitrary DBMS_TF.DESCRIBE_T structure, but this is enough in trivial cases:
                RETURN null;
            END IF;
        END;
            
        PROCEDURE fetch_rows(invert IN NUMBER DEFAULT 0, clearcontent IN NUMBER DEFAULT 0) IS
        BEGIN 
            IF clearcontent <> 0 THEN
                -- easy way to remove rows
                dbms_tf.row_replication(replication_factor => 0);
            END IF;
        END;  
    END;
    /

This toy example provides a possibility to:

* keep only specified columns
* leave out specified columns
* ignore all rows

A PTF can take tables as parameters directly:

.. code:: sql

    SELECT * FROM foo;
    -- 1 hello

    SELECT * FROM ptf.my_ptf(foo);
    -- 1 hello

...as well as lists of columns:

.. code:: sql

    -- select from a table having only the specified columns:
    SELECT * FROM ptf.my_ptf(foo, COLUMNS(col1));
    -- 1

    -- select from a table having only the non-specified columns:
    SELECT * FROM ptf.my_ptf(foo, COLUMNS(col1), 1);
    -- hello

The ``fetch_rows`` procedure can modify rows, leave them out, or even produce more rows:

.. code:: sql

    SELECT * FROM ptf.my_ptf(foo, COLUMNS(col1), 1, 1);
    -- <no results>

I guess in principle you could implement ``fetch_rows`` as you wish to produce arbitrary rows, but the PTF mechanisms provide you the possibility to do quite a lot of stuff *declaratively*. This ensures that the database engine can decide how it's going to execute the actual fetching, including utilizing parallelism if needed. This should ensure that runtime overhead is low or sometimes even zero.

PTFs are nice if you need to modify the structure/data of an existing table somehow. The implementation is quite complex compared to just writing SQL, so this is probably more suitable for implementing some generic low-level operations. There are also some limitations like PTF calls cannot be nested in the ``FROM`` clause, and they can only read and create columns of scalar types. I'm keeping my fingers crossed that at least some of these limitations are going to disappear in more recent database editions.



SQL Macros
----------

While polymorphic table functions aren't exactly something you can stitch together with your left hand in the middle of thinking about a join, `SQL Macros<https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-language-elements.html#GUID-292C3A17-2A4B-4EFB-AD38-68DF6380E5F7>`__ provide something that may help you with your ordinary querying needs.

Macros are about constructing a single query programmatically during parsing. Let's look at a simple ``take`` macro:

.. code:: sql

    CREATE OR REPLACE FUNCTION take(n NUMBER, tab DBMS_TF.TABLE_T) RETURN VARCHAR2 SQL_MACRO IS
    BEGIN
        RETURN 'SELECT * FROM tab FETCH FIRST take.n ROWS ONLY';
    END;
    /

    INSERT INTO foo VALUES(2, 'world');
    SELECT * FROM foo;
    -- 1 hello
    -- 2 world
    SELECT * FROM take(1, foo);
    -- 1 hello

A macro looks like an ordinary function returning text, but the signature is accompanied by ``SQL_MACRO`` keyword. The implementation can be just a static piece of text, but in addition, it can refer to all the parameters passed in. The parameters can contain direct table references and column lists. You can even pass in bind variables or runtime values as parameters, although they'll be null while invoking the macro at parse time.

Using macros integrates seamlessly with SQL like the other tools, but this time the result is a single SQL query optimized as a whole. You can even explain and trace it like you would an ordinary query.

If you happen to be a LISP programmer or otherwise have experience in macros, you might recognize the difficulty to see the final product behind the macro code. Oracle provides a way to see the final expanded SQL, although as it's completely expanded, it's not exactly what you might have had in mind.

.. code:: sql

    SET SERVEROUTPUT ON 
    DECLARE
        l_clob CLOB;
    BEGIN
        DBMS_UTILITY.expand_sql_text (
            input_sql_text  => 'SELECT * FROM take(1, foo)',
            output_sql_text => l_clob
        );
        DBMS_OUTPUT.put_line(l_clob);
    END;
    /

Unfortunately, macros can be considered an advanced and a rather recent feature, and those always come with bugs and "features".

.. code:: sql

    CREATE OR REPLACE FUNCTION selectcol1(tab1 DBMS_TF.TABLE_T) RETURN VARCHAR2 SQL_MACRO IS
    BEGIN
        RETURN 'SELECT col1 FROM tab1';
    END;
    /

    SELECT * FROM selectcol1(foo);
    -- 1

The previous example returns the values of ``col1`` as expected, but the next one returns static text *col1*. That might make sense when you think about it, but it certainly wasn't what I was trying to do:

.. code:: sql

    CREATE OR REPLACE FUNCTION selectcol_wtf1(tab1 DBMS_TF.TABLE_T, colname VARCHAR2) RETURN VARCHAR2 SQL_MACRO IS
    BEGIN
        RETURN 'SELECT colname FROM tab1';
    END;
    /

    SELECT * FROM selectcol_wtf1(foo, 'col1');
    -- col1

For selecting the actual column given as a parameter one would think that the following would work. After all, it's building a textual SQL equal to the one in *selectcol1*, but it doesn't even compile:

.. code:: sql

    CREATE OR REPLACE FUNCTION selectcol_wtf2(tab1 DBMS_TF.TABLE_T, colname VARCHAR2) RETURN VARCHAR2 SQL_MACRO IS
    BEGIN
        RETURN 'SELECT '||colname||' FROM tab1';
    END;
    /
    
    SELECT * FROM selectcol_wtf2(foo, 'col1');
    -- "invalid SQL text returned from SQL macro"

The example works if the column name is passed as a ``COLUMNS_T`` structure:

.. code:: sql

    CREATE OR REPLACE FUNCTION selectcol2(tab1 DBMS_TF.TABLE_T, colname DBMS_TF.COLUMNS_T) RETURN VARCHAR2 SQL_MACRO IS
    BEGIN
        RETURN 'SELECT '||colname(1)||' FROM tab1';
    END;
    /

    SELECT * FROM selectcol2(foo, COLUMNS(col1));
    -- 1

I haven't implemented a macro system myself (yet), so I'm no expert, but these feel like `unhygienic macros<https://en.wikipedia.org/wiki/Hygienic_macro>`__, where the context of the macro implementation gets mixed up with the context of the calling scope.

Macros in Oracle are extremely useful, but you need to keep in mind that they might not produce what you expect, so remember to test everything. And resist the urge to do "safe" ad-hoc refactoring.

Macros also have their limitations. You can't use a macro inside a ``WITH`` clause. This is unfortunate since it's going to reduce composability:

.. code:: sql

    WITH subq AS (
        SELECT * FROM selectcol1(foo)
    )
    SELECT * FROM subq;
    -- ORA-64630: unsupported use of SQL macro: use of SQL macro inside WITH clause is not supported

They also interact poorly with polymorphic table functions:

.. code:: sql

    select * from selectcol1(foo);
    -- 1

    WITH
        bar AS (select * from ptf.my_ptf(foo, COLUMNS(col1), 0, 1))
    SELECT * from bar;
    -- no result, since data cleared (the last '1')
    -- but when passed through a macro:

    WITH
        bar AS (select * from ptf.my_ptf(foo, COLUMNS(col1), 0, 1))
    SELECT * from selectcol1(bar);
    -- 1     -- WTF?

PTF is ignored if it's called inside a macro. It's also missing from explain plan. This is a bug in 19c, but working correctly in 21c. According to support, they aren't going to fix it in 19 series :( There may currently be several `problems in macros<https://stewashton.wordpress.com/2020/11/27/sql-table-macros-1-a-moving-target/>`__ at least in 19c.



Summary
-------

We briefly went through a couple of Oracle features, but this is just the tip of the iceberg. Oracle as well as other relational databases are constantly getting more useful features, which is great! In Oracle 21c the macro support is supplemented with `scalar macros<https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/sql_macro-clause.html#GUID-292C3A17-2A4B-4EFB-AD38-68DF6380E5F7>`__.

Hopefully, many (if not all) of these problems and limitations are going to be fixed in more recent database editions. Meanwhile, I encourage You to try out at least macros since they may turn out to be an extremely good tool to extract abstractions from your thousands of lines of views and queries.

Please let me know if you happen to know about similar features in other database products. My experience is quite limited.
