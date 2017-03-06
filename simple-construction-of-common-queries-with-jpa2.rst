Simple construction of common queries with JPA2
===============================================

In the `previous post <jpa2-still-useless.html>`__ I demonstrated an API
for executing queries. Now we need some queries. Due to some odd design
choices, JPA2 Criteria API isn't exactly the easiest API for query
construction. Maybe we could utilize its metamodel to create an easier,
statically typed way to construct simple queries. If it could help with,
let's say, 75% of all the queries in a large application, it might be
useful.

So I made a couple of small utility classes for constructing queries.
Simple, statically typed and syntactically almost a joy (well...) to
read.

Here are methods for all entities of a certain type or a single entity
with a specific ID, or multiple entities matching a set of IDs:

::

    <E extends EntityBase<?>> CriteriaQuery<E> all(Class<E> entityClass);

    <E extends EntityBase<?>> CriteriaQuery<E> single(Id<E> id);

    <E extends EntityBase<?>, ID extends Id<? super E>> CriteriaQuery<E> ofIds(Iterable<ID> ids, Class<E> entityClass)

When the query result type is an Entity, we can transform it in a few
ways related to that entity, since we can dig the selection or root
object from the query behind the scenes. We can for example project the
query to the ID or any single attribute. These are just modifications to
the underlying *select clause*:

::

    <E extends EntityBase<?>> CriteriaQuery<Id<E>> id(CriteriaQuery<E> query);

    <E extends EntityBase<?>, A extends Attribute<? super E, ?> & Bindable<R>, R> CriteriaQuery<R> value(A attribute, CriteriaQuery<E> query)

We can also add restrictions, that is, modify the where clause. There's
nothing really fancy happening here, but the true usefulness may come
from common restrictions specific to the application in question:

::

    <E extends EntityBase<?>, T> CriteriaQuery<E> attributeEquals(SingularAttribute<? super E, T> attribute, Option<T> value, CriteriaQuery<E> query);

    <E extends EntityBase<?>, A> CriteriaQuery<E> attributeIn(SingularAttribute<? super E, A> attribute, Iterable<A> values, CriteriaQuery<E> query);

    <E extends EntityBase<?>> CriteriaQuery<E> exclude(Id<E> idToExclude, CriteriaQuery<E> query);

    <E extends EntityBase<?>, ID extends Id<E>> CriteriaQuery<E> exclude(Iterable<ID> idsToExclude, CriteriaQuery<E> query);

    <E extends EntityBase<?> & Activatable, A> CriteriaQuery<E> active(CriteriaQuery<E> query);

    <E extends EntityBase<?>> CriteriaQuery<E> attributeStartsWith(SingularAttribute<? super E, String> attr, String value, CriteriaQuery<E> query);

Here's a way to use the metamodel attributes to construct a simple query
performing consecutive inner joins:

::

    <E extends EntityBase<?>,
    R1 extends EntityBase<?>,
    A1 extends Attribute<? super E, ?> & Bindable<R1>>
    CriteriaQuery<R1> related(E entity, A1 r1);

    <E extends EntityBase<?>,
    R1 extends EntityBase<?>,
    R2 extends EntityBase<?>,
    A1 extends Attribute<? super E, ?> & Bindable<R1>,
    A2 extends Attribute<? super R1, ?> & Bindable<R2>>
    CriteriaQuery<R2> related(E entity, A1 r1, A2 r2);

    //...
    // similar methods for more attributes

So, this is just a way to provide a bit less insane syntax for common
queries. Together with paging and sorting from the query execution
interface it might actually cover the most common needs.

Here's an example of querying certain municipality names of employees
from a department:

::

    // first find out the ID for Turku. One DB query, single value resultset:
    Id<Municipality> turkuId = dao.get(
        Restrict.attributeEquals(Municipality_.name, Some("Turku"),
          Query.all(Municipality.class),
      Project.id());

    // we have a department to start with. No DB queries at this point:
    Department dep = dao.getProxy(someDepId);

    // query for the names of the home municipalities of employees from dep,
    // excluding Turku for whatever reason, considering only active municipalities
    // (whatever that means...), ordering by postal code and taking page 5.
    // Single DB query, only string values in the resultset.
    List<String> municipalityNames = dao.getList(
        Restrict.active(
          Restrict.exclude(turkuId,
            Query.related(dep, Department_.employees, Employee_.homeMunicipality))),
      Page.of(5),
      Order.by(Municipality_.postalCode),
      Project.value(Municipality_.name));

The pure JPA2 Criteria Queries are almost impossible to read due to the
design choices they made. Even the most simple query cannot be
constructed with a single expression. There are some third party
libraries that provide a more sensible way for constructing queries, for
example `QueryDSL <http://www.querydsl.com/>`__ from
`Mysema <http://www.mysema.com/>`__. However, that kind of approach
requires a big leap to practically another query language. It might give
a lot more readable queries, but at the same time we may lose
possibilities to create useful abstractions if the library doesn't
provide enough extension points. Most often they don't, although I do
not have any first hand experience with QueryDSL.

The alternative approach presented here suffers from a bit awkward
syntax and a limited applicability, but on the other hand, is only a
thin wrapper around the Criteria API without causing any limitations. In
the unfortunate case that a project team decides to actually use JPA2
Criteria Queries, using this kind of approach for query construction is
not a giant leap to take.

Earlier we went through a way to execute queries various ways with
paging, ordering and simple projections. Now we have looked at a way to
construct and modify simple queries without enormous pain and without
external libraries. Next up, querying complex projections from an
arbitrary CriteriaQuery.
