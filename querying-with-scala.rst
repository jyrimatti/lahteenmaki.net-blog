Querying with Scala
===================

:Authors: Jyri-Matti Lähteenmäki
:Date: 2011-02-14

Let's say we have a simple domain model with departments and employees
(behold my imagination...). Forget all persistence or SQL related stuff,
let's just have it all in-memory:

.. code:: scala

    object InMemory {
      case class Employee(name: String, salary: Option[Int])
      case class Department(name: String, employees: Set[Employee])

      val jack = Employee("Jack Janitor", Some(2000))
      val jill = Employee("Jill Jitter", None)
      val matt = Employee("Matt Manager", Some(3250))
      val sarah = Employee("Sarah Surrender", Some(3000))
      val bill = Employee("Bill Biller", Some(4500))

      def employees = Seq(jack, jill, matt, sarah, bill)
      def departments = Seq(Department("Research and Development", Set(bill, sarah)),
                            Department("IT", Set(jack, jill)),
                            Department("Management", Set(matt)))
    }

How about querying the data?

Since the language of this example is
`Scala <http://www.scala-lang.org/>`__, I would like to write the
queries in Scala. Had I implemented this in Java, I would be wanting to
walk the object graph iterating collections. But I cannot just go and
iterate through all the employees of a department to find those whose
salary is high enough, since in real life that might cause all the
employees of the department to be loaded from the database, in some
cases one-by-one. So I'm forced to use some silly JPQL or a criteria
query to give the system the power to properly optimize my actions. The
important thing here is that what I really want to do is *not* to
iterate through a collection, but to *declare* that I'm interested in
employees belonging to a certain department. The iteration is just the
*implementation* of this problem in Java. As a friend of mine said, I'm
*over-specifying the problem* by performing the iteration.

Scala does not force this over-specification. I can use
for-comprehension for querying, which is quite abstract regarding what's
actually happening behind the scenes:

.. code:: scala

    import InMemory._

    val wellPaidEmployees = for {
      d <- departments
      e <- d.employees if e.salary.isDefined && e.salary.get > 3000
    } yield e

    val namesAndSalariesOfRnDEmployees = for {
      d <- departments if d.name startsWith "Research"
      e <- d.employees
    } yield (e.name, e.salary)

    val underpaidEmployees = for {
      e <- employees if !e.salary.isDefined || e.salary.get + 100 < 3300
    } yield (e.name, e.salary.getOrElse(0) % 42)

The syntax Scala offers is actually so abstract, that it shows in no way
that I'm actually picking stuff from in-memory collections. This
immediately raises an interesting question: what exactly is needed to
move this data to an SQL database?

First of all, the case classes defining the model are a bit too
in-memory-specific. Let's change them a bit:

.. code:: scala

    import engine._
    import engine.Types._
    import engine.Scalaq._
    package External {
      class Department extends Table {
        val name = $[String]
        val employees: ->*[Employee] = ->*(_.department)
      }
      class Employee extends Table {
        val name = $[String]
        val salary = ?[Int]
        val department: ->[Department] = ->(_.employees)
      }
      def departments = new Department
      def employees = new Employee
    }

This is actually declaring the same information, but it also builds a
model of the model, i.e. a meta model. Forgive my choice of "names" to
define properties and relations, I have a bad habit to sometimes strip
away unnecessary characters =). Now by changing the import of
``InMemory`` to ``External`` in the query examples, the same code
compiles. This is exactly what I want. The type of the data storage
should not affect my queries, since *I'm not querying the database, I'm
querying the data*.

At this point you might be thinking: *Hey, this idiot is trying to build
yet another tool to abstract away SQL completely from the application*.
That's not my intention at all. Abstraction is always a compromise. When
we abstract away the fact that our data store is an SQL database, we
give away a bunch of tools it provides. There are and always will be
queries so complex or so resource-hungry that one just cannot give a
satisfying implementation without assuming an SQL backend. At some point
that's not enough, and one needs to know it's an Oracle 11g database.
Therefore, every abstraction like this should only strive to solve 95%
or so of the cases.

Back to the queries. After changing the import clause the
for-comprehensions don't return the actual data anymore, they return
some objects containing the information needed to later construct the
actual query against the data store, whatever it is. You might have
noticed that none of the example codes had anything related to SQL
(well, the base class name \`Table should probably be something
else...). If we add some jdbc-connection-related helper methods (not
listed), we can actually perform these queries against a database:

.. code:: scala

    val Seq(a,b,c) = transaction("jdbc:h2:mem:test") { implicit c =>
      import engine.sql._
      val session = new Session with H2Dialect
      import session._
      execute(generateDDL(departments, employees))
      testData foreach execute
      Seq(executeQuery(generateQuery(wellPaidEmployees)),
          executeQuery(generateQuery(namesAndSalariesOfRnDEmployees)),
          executeQuery(generateQuery(underpaidEmployees)))
    }

First the SQL schema is created based on the model definition and
populated with some test data. Then the SQL corresponding to the queries
are generated and the resulting strings executed. Printing the final
three string objects will print the actual results of the queries.

The current implementation of the engine is rather simple with a few
hundred lines of somewhat readable Scala. This means that although
implicits are being used quite heavily, the concept as a whole is still
quite easily comprehensible.

So, is this somehow revolutionary? Hell no. It's a simple example
performing simple queries. All the important stuff like composability or
alternative data stores are still missing. On the other hand, does e.g.
JPA have those properties?

Various nice features can be spotted in this implementation (or could
be, if you looked at my source code):

-  pure, static, compiled Scala
-  statically and strongly typed (one cannot compare a string to an
   integer, or directly use an optional value...)
-  DDL generation
-  some basic SQL features including inner joins, comparisons, string
   matching and some arithmetic functions
-  possibility to pass data store specific parameters (like max length
   of varchar) to the model properties
-  custom types ("user types")

Aggregate functions seem also implementable, though I don't yet have
them finished. Composition is something I must experiment with soon
since it's an important feature. Other experiments include
inserts/updates, populating objects with the data easily, some other
data store types... These might bring some additional noise to the model
declaration but hopefully keep the queries abstract.

There is a project called `ScalaQuery <http://scalaquery.org/>`__ which
has implemented something like this. I do not like it's approach,
though, which is stated in its overview in the web site (I highlighted
the annoying parts):

    ScalaQuery is an API / DSL (domain specific language) built on top
    of **JDBC** for accessing **relational databases** in Scala.

I consider basic querying as an abstract thing having no relation to the
type of the data store, but ScalaQuery is making ties to things like
JDBC and SQL. This is also visible in its syntax. I haven't yet found a
need to make that kind of deviations from regular Scala, but it might be
that I just haven't been there yet.

The examples I've given are just my initial experiments, and the syntax
is most likely going to change at least slightly. I'm hoping that
additional features won't force me to bring any additional verbosity,
though. I will post a working jar-file later so that you can try it if
you have any interest. I will also post all source code in the future,
when I'm done enough experimenting.

If You have any thoughts of this kind of abstract querying in Scala, I'd
be glad to hear your thoughts. Now I'm heading to
`JFokus <http://jfokus.se/>`__, see you there.
