Java Persistence API 2. Still useless?
======================================

:Authors: Jyri-Matti Lähteenmäki
:Date: 2012-08-10
:Status: Published

In my day job I have the "privilege" to use JPA
(`Hibernate <http://www.hibernate.org/>`__ in practice) for persistence.
So when JPA2 was released I was eager to find out if they had actually
corrected their mistakes and made a framework comparable to competitors.
Well, they hadn't.

Don't get me wrong. I actually don't hate Hibernate. I just hate the
`ORM <http://en.wikipedia.org/wiki/Object-relational_mapping>`__ part of
it, since ORM is broken. Abstractions are a must, and SQL-level is IMHO
a bit too low-level for "regular stuff". Hibernate (or an alternative of
your choice, I don't really care) is useful for stuff like typing, query
generation and since the introduction of `JPA2
Metamodel <http://docs.jboss.org/hibernate/orm/4.0/hem/en-US/html/metamodel.html>`__
also for describing the table structure at the application level.

Shortly after Hibernate support for JPA2 was officially released we
decided to try it out in a real project. We chose to use the new
Criteria API due to static type safety and pure interest. Well, as a
colleague put it, the Criteria API is
`write-only <http://en.wikipedia.org/wiki/Write-only_language>`__:
nearly unreadable. Who's the idiot that decided to make it the way it
is?

Anyway, composability - as we all know - is the mother of all software
design patterns. Functional programming languages are composable by
nature. Pure SQL is composable by nature. So, how come people tend to
completely forget composability when programming in Java?

I spent hours and hours trying to figure out how to create composable
queries with the Criteria API, but I just couldn't come up with anything
useful. Every strategy seemed equally awkward. Had they really created
yet another non-composable sql-api?

Yes, I believe they had. So I decided to try something else. If I cannot
reuse queries to construct other queries, maybe I could at least reuse
the whole queries? I decided to separate the queries from their
execution (if this feels somewhat obvious to you then I guess I'm just
way behind you). This way I could create an arbitrary query of an entity
E and use it to query for an E, many E:s, count or existence of E:s or -
this is the good part - any (trivial) projection of E. And the same with
either paging or trivial sorting or both...

Assume we have an arbitrarily complex query returning rows of
Department. Then we can use that same query for different use cases:

.. code:: java

    Page page = Page.FIRST;
    CriteriaQuery<Department> q = ...;

    Department dep              = dao.get(q);
    Option<Department> dep      = dao.find(q);
    long amountOfDeps           = dao.count(q);
    boolean depsExist           = dao.exists(q);
    Option<Department> firstDep = dao.findFirst(q, Order.by(Department_.name));
    Collection<Department> deps = dao.getList(q);
    List<Department> deps       = dao.getList(q, page, Order.by(Department_.name));
                                  dao.removeAll(q);

I made a really simple API to execute the queries. The idea was to
restrict the possibilities of the developer as much as possible, so that
there's no chance for screw-ups and thus less need for testing. I
dislike testing and I loath
`TDD <http://en.wikipedia.org/wiki/Test-driven_development>`__ since
it's completely distorted as a way to think, but that rant is for
another blog post...

The API also supports execution of native and HQL queries, but their
usage is limited since they don't contain the metadata needed to do
stuff. The idea was that the business logic could just pick a query and
execute it (or some projection etc of it) without needing to know its
implementation. But on the other hand, it's nice that the compiler
complains for example when the query implementation is changed to not
support projections.

I use type signatures as much as possible to restrict how the specific
queries can be executed. For example, remove-method can only be used for
queries resulting in Removable entities, ordering can be used only for
queries resulting in entities, and with the help of the metamodel,
projections and sorting can only be made to existing attributes.

Here are the methods for executing the previous queries. Please correct
me if the signatures are sub-optimal:

.. code:: java

    <T> T get(CriteriaQuery<T> query) throws NoResultException, NonUniqueResultException;

    <T> Option<T> find(CriteriaQuery<T> query) throws NonUniqueResultException;

    long count(CriteriaQuery<?> query);

    boolean exists(CriteriaQuery<?> query);

    <E extends EntityBase<?>> Option<E> findFirst(CriteriaQuery<E> query, Iterable<? extends Order<? super E,?>> ordering);

    <T> Collection<T> getList(CriteriaQuery<T> query);

    <E extends EntityBase<?>> List<E> getList(CriteriaQuery<E> query, Page page, Iterable<? extends Order<? super E, ?>> ordering);

    <ID extends Id<E>, E extends EntityBase<ID> & Removable> void removeAll(CriteriaQuery<E> query)

And here's one more and an example of querying a projection:

.. code:: java

    <E extends EntityBase<?>,R> Collection<R> 
    getList(CriteriaQuery<E> query, ConstructorMeta_<E,R> constructor);

    class DepartmentDto {
      DepartmentDto(Id<Department> id, String name, Set<Manager> managers) {...}
    }

    CriteriaQuery<Department> query = ...;
    Collection<DepartmentDto> dto = dao.get(query,
                                    DepartmentDto_.c1(Department_.id,
                                                      Department_.name,
                                                      Department_.managers));

There were some problems, as there always is. Apparently the Criteria
API is not designed in a way that the queries could be modified freely.
So we had to make sure that the queries are always constructed with the
parameterles variant,
`CriteriaBuilder.createQuery() <http://docs.oracle.com/javaee/6/api/javax/persistence/criteria/CriteriaBuilder.html#createQuery()>`__,
to result in Object, and then casted to the correct type. Not a real
problem, but a bit of a nasty hack. Later I removed that limitation by
copying the queries when needed, but apparently they are not designed to
be copied either =) So, the whole thing might mysteriously fail some day
with complex queries. Welcome to the mutable, stateful world of Java
filled with horrible APIs...

In the end, I'm really satisfied with this query-execution-separation
since it greatly increased reusability of our queries. And still
remained statically type safe. In the next blog post I will present "the
next step towards LINQ": How to construct queries with minimal (well,
sort of) pain yet statically (well, mostly) typed. Turns out that we can
easily construct queries for whole entity hierarchies (or something...)
populating `DTOs <http://en.wikipedia.org/wiki/Data_transfer_object>`__
through constructors type safely, without
`n+1-problems <http://stackoverflow.com/questions/97197/what-is-the-n1-selects-problem>`__.
The approach has some limitations, but it might well be enough for 90%
(or not...) of queries, which would be a blast =)
