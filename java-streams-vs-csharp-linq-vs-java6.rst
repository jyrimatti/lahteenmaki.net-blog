Java Streams vs C# LINQ vs Java6
================================

:Authors: Jyri-Matti Lähteenmäki
:Date: 2013-04-10

A while back I ran into an article comparing C# LINQ to the upcoming
Java8 Streams API:
http://blog.informatech.cr/2013/03/24/java-streams-preview-vs-net-linq/.

I'm not really experienced with C# but I have a feeling that the
language as a whole is quite verbose and, well, bad? Except for LINQ
which performs magic with monadic comprehension.

I've been coding in Java for the most of my career, so I know a thing or
two about it:

1. it's really verbose.
2. it's really, *really*, verbose.
3. it's not nearly as verbose as you think. It's often just bad practice
   and inferior style that makes it so verbose and incomprehensible.

Since Java is still the language of my enterprise-day-job, I decided to
ease my pain a bit, so I implemented `my own functional utility
library <https://github.com/solita/functional-utils>`__. I got a bit
carried away, so I ended up with some annotation processors to bring
something like poor-mans-first-class-functions into Java.

Since the library often provides rather clean ways to express ones
intent, I wanted to see how it would compare to LINQ and Java Streams.
So here it goes, examples from the Informatech blog supplemented with
examples using plain old Java6 (released in 2007) using my functional
library with annotation processors.

#Edit: I have written a
`follow-up <java-streams-vs-c-linq-vs-java6-updated.html>`_
with updated examples.

Challenge 1: Filtering
----------------------

LINQ :

.. code:: cs

    string[] names = { "Sam", "Pamela", "Dave", "Pascal", "Erik" };
    List<string> filteredNames = names.Where(c => c.Contains("am"))
                                      .ToList();

Java Streams :

.. code:: java

    String[] names = {"Sam","Pamela", "Dave", "Pascal", "Erik"};
    List<String> filteredNames = stream(names)
                     .filter(c -> c.contains("am"))
                     .collect(toList());

Java6 :

.. code:: java

    String[] names = { "Sam", "Pamela", "Dave", "Pascal", "Erik" };
    List<string> filteredNames = newList(filter(names, contains("am")));

Challenge 2: Indexed Filtering
------------------------------

LINQ :

.. code:: cs

    string[] names = { "Sam", "Pamela", "Dave", "Pascal", "Erik" };
    var nameList = names.Where((c, index) => c.Length <= index + 1).ToList();

Java Streams :

.. code:: java

    String[] names = {"Sam","Pamela", "Dave", "Pascal", "Erik"};

    List<String> nameList;
    Stream<Integer> indices = intRange(1, names.length).boxed();
    nameList = zip(indices, stream(names), SimpleEntry::new)
                .filter(e -> e.getValue().length() <= e.getKey())
                .map(Entry::getValue)
                .collect(toList());

Java6 :

.. code:: java

    String[] names = { "Sam", "Pamela", "Dave", "Pascal", "Erik" };
    List<String> nameList = newList(map(filter(zipWithIndex(names), pred),
                                        Transformers.<String> right()));

    static boolean pred(Map.Entry<Integer, String> candidate) {
        return candidate.getValue().length() <= candidate.getKey() + 1;
    }

Challenge 3: Selecting/Mapping
------------------------------

LINQ :

.. code:: cs

    List<string> nameList1 = new List(){ "Anders", "David", "James",
                                         "Jeff", "Joe", "Erik" };
    nameList1.Select(c => "Hello! " + c).ToList()
             .ForEach(c => Console.WriteLine(c));

Java Streams :

.. code:: java

    List<String> nameList1 = asList("Anders", "David", "James",
                                    "Jeff", "Joe", "Erik");
    nameList1.stream()
         .map(c -> "Hello! " + c)
         .forEach(System.out::println);

Java6 :

.. code:: java

    List<String> nameList1 = newList("Anders", "David", "James", "Jeff", "Joe", "Erik");
    foreach(map(nameList1, prepend("Hello! ")),
                PrintStream_.println8.apply(System.out));

Challenge 4: Selecting Many/Flattening
--------------------------------------

LINQ :

.. code:: cs

    Dictionary<string, List<string>> map = new Dictionary<string,List<string>>();
    map.Add("UK", new List<string>() {"Bermingham", "Bradford", "Liverpool"});
    map.Add("USA", new List<string>() {"NYC", "New Jersey", "Boston", "Buffalo"});
    var cities = map.SelectMany(c => c.Value).ToList();

Java Streams :

.. code:: java

    Map<String, List<String>> map = new LinkedHashMap<>();
    map.put("UK", asList("Bermingham","Bradford","Liverpool"));
    map.put("USA", asList("NYC","New Jersey","Boston","Buffalo"));

    FlatMapper<Entry<String, List<String>>,String> flattener;
    flattener = (entry,consumer) -> { entry.getValue().forEach(consumer); };

    List<String> cities = map.entrySet()
                 .stream()
                 .flatMap( flattener )
                 .collect(toList());

Java6 :

.. code:: java

    Map<String, List<String>> map = newMap(
        Pair.of("UK", newList("Bermingham", "Bradford", "Liverpool")),
        Pair.of("USA", newList("NYC", "New Jersey", "Boston", "Buffalo")));
    List<String> cities = newList(flatten(map.values()));

Challenge 5: Taking an Arbitrary Number of Items
------------------------------------------------

LINQ :

.. code:: cs

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 };
    var first4 = numbers.Take(4).ToList();

Java Streams :

.. code:: java

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,13 };

    List<Integer> firstFour;
    firstFour = stream(numbers).limit(4)
                               .boxed()
                               .collect(toList());

Java6 :

.. code:: java

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 };
    List<Integer> firstFour = newList(take(newArray(numbers), 4));

Challenge 6: Taking Items Based on Predicate
--------------------------------------------

LINQ :

.. code:: cs

    string[] moreNames = { "Sam", "Samuel", "Dave", "Pascal", "Erik",  "Sid" };
    var sNames = moreNames.TakeWhile(c => c.StartsWith("S"));

Java Streams :

.. code:: java

    String[] names  = { "Sam","Samuel","Dave","Pascal","Erik","Sid" };

    List<String> found;
    found = stream(names).collect(partitioningBy( c -> c.startsWith("S")))
                         .get(true);

Java6 :

.. code:: java

    String[] names = { "Sam", "Samuel", "Dave", "Pascal", "Erik", "Sid" };
    List<String> found = newList(takeWhile(names, startsWith("S")));

Challenge 7: Skipping an Arbitrary Number of Items
--------------------------------------------------

LINQ :

.. code:: cs

    string[] vipNames = { "Sam", "Samuel", "Samu", "Remo", "Arnold","Terry" };
    var skippedList = vipNames.Skip(3).ToList();//Leaving the first 3.

Java Streams :

.. code:: java

    String[] vipNames = { "Sam", "Samuel", "Samu", "Remo", "Arnold","Terry" };

    List<String> skippedList;
    skippedList = stream(vipNames).substream(3).collect(toList());

Java6 :

.. code:: java

    String[] vipNames = { "Sam", "Samuel", "Samu", "Remo", "Arnold", "Terry" };
    List<String> skippedList = newList(drop(vipNames, 3));

Challenge 8: Skipping Items Based on Predicate
----------------------------------------------

LINQ :

.. code:: cs

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20 };
    var skippedList = numbers.SkipWhile(c => c < 10);

Java Streams :

.. code:: java

    //With current streams API I found no way to implement this idiom.

Java6 :

.. code:: java

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20 };
    List<Integer> skippedList = newList(dropWhile(newArray(numbers), lessThan(10)));

Challenge 9: Ordering/Sorting Elements
--------------------------------------

LINQ :

.. code:: cs

    string[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = friends.OrderBy(c => c).ToArray();

Java Streams :

.. code:: java

    String[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = stream(friends).sorted().toArray(String[]::new);

Java6 :

.. code:: java

    String[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = newArray(sort(friends), String.class);

Challenge 10: Ordering/Sorting Elements by Specific Criterium
-------------------------------------------------------------

LINQ :

.. code:: cs

    string[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = friends.OrderBy(c => c.Length).ToArray();

Java Streams :

.. code:: java

    String[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = stream(friends)
               .sorted(comparing((ToIntFunction<String>)String::length))
               .toArray(String[]::new);

Java6 :

.. code:: java

    String[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = newArray(sort(friends, by(String_.length)), String.class);

Challenge 11: Ordering/Sorting Elements by Multiple Criteria
------------------------------------------------------------

LINQ :

.. code:: cs

    string[] fruits = {"grape", "passionfruit", "banana",
                       "apple", "orange", "raspberry",
                       "mango", "blueberry" };

    //Sort the strings first by their length and then alphabetically.
    //preserving the first order.
    var sortedFruits = fruits.OrderBy(fruit =>fruit.Length)
                             .ThenBy(fruit => fruit);

Java Streams :

.. code:: java

    String[] fruits = {"grape", "passionfruit", "banana","apple",
                       "orange", "raspberry","mango", "blueberry" };

    Comparator<String> comparator;
    comparator = comparing((Function<String,Integer>)String::length,
                           Integer::compare)
                .thenComparing((Comparator<String>)String::compareTo);

    fruits = stream(fruits) .sorted(comparator)
                            .toArray(String[]::new);

Java6 :

.. code:: java

    String[] fruits = { "grape", "passionfruit", "banana", "apple",
                        "orange", "raspberry", "mango", "blueberry" };
    fruits = newArray(sort(fruits, by(String_.length).then(
                                   byNatural())), String.class);

Challenge 12: Grouping by a Criterium
-------------------------------------

LINQ :

.. code:: cs

    string[] names = {"Sam", "Samuel", "Samu", "Ravi", "Ratna",  "Barsha"};
    var groups = names.GroupBy(c => c.Length);

Java Streams :

.. code:: java

    String[] names = {"Sam", "Samuel", "Samu", "Ravi", "Ratna",  "Barsha"};

    Map<Integer,List<String>> groups;
    groups = stream(names).collect(groupingBy(String::length));

Java6 :

.. code:: java

    String[] names = { "Sam", "Samuel", "Samu", "Ravi", "Ratna", "Barsha" };
    Map<Integer, List<String>> groups = groupBy(names, String_.length);

Challenge 13: Filter Distinct Elements
--------------------------------------

LINQ :

.. code:: cs

    string[] songIds = {"Song#1", "Song#2", "Song#2", "Song#2", "Song#3", "Song#1"};
    //This will work as strings implement IComparable
    var uniqueSongIds = songIds.Distinct();

Java Streams :

.. code:: java

    String[] songIds = {"Song#1", "Song#2", "Song#2", "Song#2", "Song#3", "Song#1"};
    //according to Object.equals
    stream(songIds).distinct();

Java6 :

.. code:: java

    String[] songIds = { "Song#1", "Song#2", "Song#2", "Song#2", "Song#3", "Song#1" };
    newSet(songIds);

Challenge 14: Union of Two Sets
-------------------------------

LINQ :

.. code:: cs

    List<string> friends1 = new List<string>() {"Anders", "David","James",
                                                "Jeff", "Joe", "Erik"};
    List<string> friends2 = new List<string>() { "Erik", "David", "Derik" };
    var allMyFriends = friends1.Union(friends2);

Java Streams :

.. code:: java

    List<String> friends1 = asList("Anders","David","James","Jeff","Joe","Erik");
    List<String> friends2 = asList("Erik","David","Derik");
    Stream<String> allMyFriends = concat(friends1.stream(),
                                         friends2.stream()).distinct();

Java6 :

.. code:: java

    List<String> friends1 = newList("Anders", "David", "James", "Jeff", "Joe", "Erik");
    List<String> friends2 = newList("Erik", "David", "Derik");
    Set<String> allMyFriends = union(newSet(friends1), newSet(friends2));

Challenge 15: First Element
---------------------------

LINQ :

.. code:: cs

    string[] otherFriends = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    string firstName = otherFriends.First();
    string firstNameConditional = otherFriends.First(c => c.Length == 5);

Java Streams :

.. code:: java

    String[] otherFriends = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    Optional<String> found = stream(otherFriends).findFirst();

    Optional<String> maybe = stream(otherFriends).filter(c -> c.length() == 5)
                                                 .findFirst();
    if(maybe.isPresent()) {
       //do something with found data
    }

Java6 :

.. code:: java

    String[] otherFriends = { "Sam", "Danny", "Jeff", "Erik", "Anders", "Derik" };
    Option<String> found = headOption(otherFriends);
    Option<String> maybe = find(otherFriends, String_.length.andThen(equalTo(5)));
    for (String m: maybe) {
        // ...
    }

Challenge 16: Generate a Range of Numbers
-----------------------------------------

LINQ :

.. code:: cs

    var multiplesOfEleven = Enumerable.Range(1, 100).Where(c => c % 11 == 0);

Java Streams :

.. code:: java

    IntStream multiplesOfEleven = intRange(1,100).filter(n -> n % 11 == 0);

Java6 :

.. code:: java

    Iterable<Integer> multiplesOfEleven = filter(range(1, 100), mod(11).andThen(equalTo(0)));

Challenge 17: All
-----------------

LINQ :

.. code:: cs

    string[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    bool x = persons.All(c => c.Length == 5);

Java Streams :

.. code:: java

    String[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    boolean x = stream(persons).allMatch(c -> c.length() == 5);

Java6 :

.. code:: java

    String[] persons = { "Sam", "Danny", "Jeff", "Erik", "Anders", "Derik" };
    boolean x = forAll(persons, String_.length.andThen(equalTo(5)));

Challenge 18: Any
-----------------

LINQ :

.. code:: cs

    string[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    bool x = persons.Any(c => c.Length == 5);

Java Streams :

.. code:: java

    String[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    boolean x = stream(persons).anyMatch(c -> c.length() == 5);

Java6 :

.. code:: java

    String[] persons = { "Sam", "Danny", "Jeff", "Erik", "Anders", "Derik" };
    boolean x = exists(persons, String_.length.andThen(equalTo(5)));

Challenge 19: Zip
-----------------

LINQ :

.. code:: cs

    string[] salutations = {"Mr.", "Mrs.", "Ms", "Master"};
    string[] firstNames = {"Samuel", "Jenny", "Joyace", "Sam"};
    string lastName = "McEnzie";

    salutations.Zip(firstNames, (sal, first) => sal + " " + first)
               .ToList()
               .ForEach(c => Console.WriteLine(c + " " + lastName));

Java Streams :

.. code:: java

    String[] salutations = {"Mr.", "Mrs.", "Ms", "Master"};
    String[] firstNames = {"Samuel", "Jenny", "Joyace", "Sam"};
    String lastName = "McEnzie";

    zip(
        stream(salutations),
        stream(firstNames),
        (sal,first) -> sal + " " +first)
    .forEach(c -> { System.out.println(c + " " + lastName); });

Java6 :

.. code:: java

    String[] salutations = { "Mr.", "Mrs.", "Ms", "Master" };
    String[] firstNames = { "Samuel", "Jenny", "Joyace", "Sam" };
    String lastName = "McEnzie";

    foreach(map(zip(salutations, firstNames, repeat(lastName)), mkString(" ")),
            PrintStream_.println8.apply(System.out));

Conclusion
----------

Based on these examples I have a funny feeling that Java8 Streams API is
going to be a failure. And since developers will not be able to extend
it with useful constructs, it may well end up being just another nail in
the coffin.

Of these examples, personally, I find the Java6 code to be the most
readable. Even with its oddities, of which most are caused by the
original authors decision to use *ints* (instead of *Integers*) and
*Lists* (instead of *Iterables*). The ability to do this has been around
since 2007, and Java8 will be released in... 2014?

I'm a bit biased, though, so what do you think?
