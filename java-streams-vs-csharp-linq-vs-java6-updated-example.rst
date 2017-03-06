Java Streams vs C# LINQ vs Java6 - updated examples
===================================================

:Authors: Jyri-Matti Lähteenmäki
:Date: 2014-05-17

Java 8 is published. This post is a rewrite of my `previous
one <./java-streams-vs-csharp-linq-vs-java6-updated-example.html>`__
with updated examples. I added a third example to each challenge
demonstrating how my functional-utils library could be used with
lambdas.

Challenge 1: Filtering
----------------------

LINQ :

.. code:: cs

    string[] names = { "Sam", "Pamela", "Dave", "Pascal", "Erik" };
    List<string> filteredNames = names.Where(c => c.Contains("am"))
                                      .ToList();

Java :

.. code:: java

    String[] names = {"Sam","Pamela", "Dave", "Pascal", "Erik"};

    // Java Streams
    List<String> filtered8 = stream(names).filter(c -> c.contains("am")).collect(toList());

    // Java 6 with functional-utils
    List<String> filtered6 = newList(filter(String_.contains.apply(_, "am"), names));

    // Java 8 with functional-utils
    List<String> filtered_ = newList(filter(c -> c.contains("am"), names));

Challenge 2: Indexed Filtering
------------------------------

LINQ :

.. code:: cs

    string[] names = { "Sam", "Pamela", "Dave", "Pascal", "Erik" };
    var nameList = names.Where((c, index) => c.Length <= index + 1).ToList();

Java :

.. code:: java

    static boolean pred(int index, String name) {
            return name.length() <= index + 1;
        }
    // ...
    String[] names = {"Sam","Pamela", "Dave", "Pascal", "Erik"};

    // Java Streams
    OfInt indices = IntStream.range(1, names.length).iterator();
    List<String> nameList8 = stream(names).map(c -> Pair.of(indices.next(), c))
                                          .filter(c -> c.getValue().length() <= c.getKey())
                                          .map(Pair::getValue)
                                          .collect(toList());

    // Java 6 with functional-utils
    List<String> nameList6 = newList(map(Tuple2_.<String>_2(),
                                         filter(pred, zipWithIndex(names))));

    // Java 8 with functional-utils
    List<String> nameList_ = newList(map(Tuple2::get_2,
                                         filter(t2 -> t2._2.length() <= t2._1+1,
                                                zipWithIndex(names))));

Challenge 3: Selecting/Mapping
------------------------------

LINQ :

.. code:: cs

    List<string> nameList1 = new List(){ "Anders", "David", "James",
                                         "Jeff", "Joe", "Erik" };
    nameList1.Select(c => "Hello! " + c).ToList()
             .ForEach(c => Console.WriteLine(c));

Java :

.. code:: java

    List<String> nameList = Arrays.asList("Anders", "David", "James","Jeff", "Joe", "Erik");

    // Java Streams
    nameList.stream().map(c -> "Hello! " + c).forEach(System.out::println);

    // Java 6 with functional-utils
    foreach(PrintStream_.println8.ap(System.out),
            map(String_.concat.ap("Hello! "), nameList));

    // Java 8 with functional-utils
    foreach(System.out::println, map(c -> "Hello! " + c, nameList));

Challenge 4: Selecting Many/Flattening
--------------------------------------

LINQ :

.. code:: cs

    Dictionary<string, List<string>> map = new Dictionary<string,List<string>>();
    map.Add("UK", new List<string>() {"Bermingham", "Bradford", "Liverpool"});
    map.Add("USA", new List<string>() {"NYC", "New Jersey", "Boston", "Buffalo"});
    var cities = map.SelectMany(c => c.Value).ToList();

Java :

.. code:: java

    Map<String, List<String>> map = new HashMap<>();
            map.put("UK", Arrays.asList("Bermingham","Bradford","Liverpool"));
            map.put("USA", Arrays.asList("NYC","New Jersey","Boston","Buffalo"));

    // Java Streams
    List<String> cities8 = map.entrySet().stream()
                                         .map(Map.Entry::getValue)
                                         .flatMap(List::stream)
                                         .collect(toList());

    // Java 6 with functional-utils
    List<String> cities6 = newList(flatMap(Map_.Entry_.getValue(), map.entrySet()));

    // Java 8 with functional-utils
    List<String> cities_ = newList(flatMap(Map.Entry::getValue, map.entrySet()));

Challenge 5: Taking an Arbitrary Number of Items
------------------------------------------------

LINQ :

.. code:: cs

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 };
    var first4 = numbers.Take(4).ToList();

Java :

.. code:: java

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,13 };

    // Java Streams
    List<Integer> firstFour8 = stream(numbers).limit(4).boxed().collect(toList());

    // Java 6 with functional-utils
    List<Integer> firstFour6 = newList(take(4, newArray(numbers)));

    // Java 8 with functional-utils
    List<Integer> firstFour_ = newList(take(4, newArray(numbers)));

Challenge 6: Taking Items Based on Predicate
--------------------------------------------

LINQ :

.. code:: cs

    string[] moreNames = { "Sam", "Samuel", "Dave", "Pascal", "Erik",  "Sid" };
    var sNames = moreNames.TakeWhile(c => c.StartsWith("S"));

Java :

.. code:: java

    String[] names = { "Sam","Samuel","Dave","Pascal","Erik","Sid" };

    // Java Streams
    // Still cannot do this, since takeWhile is not in the API.

    // Java 6 with functional-utils
    List<String> found6 = newList(takeWhile(String_.startsWith.apply(_, "S"), names));

    // Java 8 with functional-utils
    List<String> found_ = newList(takeWhile(c -> c.startsWith("S"), names));

Challenge 7: Skipping an Arbitrary Number of Items
--------------------------------------------------

LINQ :

.. code:: cs

    string[] vipNames = { "Sam", "Samuel", "Samu", "Remo", "Arnold","Terry" };
    var skippedList = vipNames.Skip(3).ToList();//Leaving the first 3.

Java :

.. code:: java

    String[] vipNames = { "Sam", "Samuel", "Samu", "Remo", "Arnold","Terry" };

    // Java Streams
    List<String> skippedList8 = stream(vipNames).skip(3).collect(toList());

    // Java 6 with functional-utils
    List<String> skippedList6 = newList(drop(3, vipNames));

    // Java 8 with functional-utils
    List<String> skippedList_ = newList(drop(3, vipNames));

Challenge 8: Skipping Items Based on Predicate
----------------------------------------------

LINQ :

.. code:: cs

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20 };
    var skippedList = numbers.SkipWhile(c => c < 10);

Java :

.. code:: java

    int[] numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20 };

    // Java Streams
    // Still cannot do this, since skipWhile is not in the API.

    // Java 6 with functional-utils
    List<Integer> skippedList6 = newList(dropWhile(lessThan(10), newArray(numbers)));

    // Java 8 with functional-utils
    List<Integer> skippedList_ = newList(dropWhile(c -> c < 10, newArray(numbers)));

Challenge 9: Ordering/Sorting Elements
--------------------------------------

LINQ :

.. code:: cs

    string[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = friends.OrderBy(c => c).ToArray();

Java :

.. code:: java

    String[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };

    // Java Streams
    String[] friends8 = stream(friends).sorted().toArray(String[]::new);

    // Java 6 with functional-utils
    String[] friends6 = newArray(String.class, sort(friends));

    // Java 8 with functional-utils
    String[] friends_ = newArray(String.class, sort(friends));

Challenge 10: Ordering/Sorting Elements by Specific Criterium
-------------------------------------------------------------

LINQ :

.. code:: cs

    string[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };
    friends = friends.OrderBy(c => c.Length).ToArray();

Java :

.. code:: java

    String[] friends = { "Sam", "Pamela", "Dave", "Anders", "Erik" };

    // Java Streams
    String[] friends8 = stream(friends).sorted(comparing(String::length))
                                       .toArray(String[]::new);

    // Java 6 with functional-utils
    String[] friends6 = newArray(String.class, sort(by(String_.length), friends));

    // Java 8 with functional-utils
    String[] friends_ = newArray(String.class, sort(by(String::length), friends));

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

Java :

.. code:: java

    String[] fruits = {"grape", "passionfruit", "banana","apple", "orange", "raspberry" };

    // Java Streams
    String[] fruits8 = stream(fruits).sorted(comparing(String::length)
                                            .thenComparing(naturalOrder()))
                                     .toArray(String[]::new);

    // Java 6 with functional-utils
    String[] fruits6 = newArray(String.class,
                                sort(by(String_.length).then(byNatural()), fruits));

    // Java 8 with functional-utils
    String[] fruits_ = newArray(String.class,
                                sort(by(String::length).then(byNatural()), fruits));

Challenge 12: Grouping by a Criterium
-------------------------------------

LINQ :

.. code:: cs

    string[] names = {"Sam", "Samuel", "Samu", "Ravi", "Ratna",  "Barsha"};
    var groups = names.GroupBy(c => c.Length);

Java :

.. code:: java

    String[] names = {"Sam", "Samuel", "Samu", "Ravi", "Ratna", "Barsha"};

    // Java Streams
    Map<Integer,List<String>> groups8 = stream(names).collect(groupingBy(String::length));

    // Java 6 with functional-utils
    Map<Integer, List<String>> groups6 = groupBy(String_.length, names);

    // Java 8 with functional-utils
    Map<Integer, List<String>> groups_ = groupBy(String::length, names);

Challenge 13: Filter Distinct Elements
--------------------------------------

LINQ :

.. code:: cs

    string[] songIds = {"Song#1", "Song#2", "Song#2", "Song#2", "Song#3", "Song#1"};
    //This will work as strings implement IComparable
    var uniqueSongIds = songIds.Distinct();

Java :

.. code:: java

    String[] songIds = {"Song#1", "Song#2", "Song#2", "Song#2", "Song#3", "Song#1"};

    // Java Streams
    List<String> distinct8 = stream(songIds).distinct().collect(toList());

    // Java 6 with functional-utils
    List<String> distinct6 = newList(distinct(songIds));

    // Java 8 with functional-utils
    List<String> distinct_ = newList(distinct(songIds));

Challenge 14: Union of Two Sets
-------------------------------

LINQ :

.. code:: cs

    List<string> friends1 = new List<string>() {"Anders", "David","James",
                                                "Jeff", "Joe", "Erik"};
    List<string> friends2 = new List<string>() { "Erik", "David", "Derik" };
    var allMyFriends = friends1.Union(friends2);

Java :

.. code:: java

    List<String> friends1 = Arrays.asList("Anders","David","James","Jeff","Joe","Erik");
    List<String> friends2 = Arrays.asList("Erik","David","Derik");

    // Java Streams
    Set<String> allMyFriends8 = Stream.concat(friends1.stream(), friends2.stream())
                                      .collect(toSet());

    // Java 6 with functional-utils
    Set<String> allMyFriends6 = union(newSet(friends1), newSet(friends2));

    // Java 8 with functional-utils
    Set<String> allMyFriends_ = union(newSet(friends1), newSet(friends2));

Challenge 15: First Element
---------------------------

LINQ :

.. code:: cs

    string[] otherFriends = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    string firstName = otherFriends.First();
    string firstNameConditional = otherFriends.First(c => c.Length == 5);

Java :

.. code:: java

    String[] otherFriends = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};

    // Java Streams
    Optional<String> firstName8 = stream(otherFriends).findFirst();
    Optional<String> firstNameCondl8 = stream(otherFriends).filter(c -> c.length() == 5)
                                                           .findFirst();

    // Java 6 with functional-utils
    Option<String> firstName6 = headOption(otherFriends);
    Option<String> firstNameCondl6 = find(String_.length.andThen(equalTo(5)), otherFriends);

    // Java 8 with functional-utils
    Option<String> firstName_ = headOption(otherFriends);
    Option<String> firstNameCond_ = find(c -> c.length() == 5, otherFriends);

Challenge 16: Generate a Range of Numbers
-----------------------------------------

LINQ :

.. code:: cs

    var multiplesOfEleven = Enumerable.Range(1, 100).Where(c => c % 11 == 0);

Java :

.. code:: java

    // Java Streams
    List<Integer> multiplesOfEleven8 = IntStream.rangeClosed(1,100)
                                                .filter(n -> n % 11 == 0)
                                                .boxed()
                                                .collect(toList());

    // Java 6 with functional-utils
    List<Integer> multiplesOfEleven6 = newList(filter(mod(11).andThen(equalTo(0)),
                                                      range(1, 100)));

    // Java 8 with functional-utils
    List<Integer> multiplesOfEleven_ = newList(filter(c -> c % 11 == 0, range(1, 100)));

Challenge 17: All
-----------------

LINQ :

.. code:: cs

    string[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    bool x = persons.All(c => c.Length == 5);

Java :

.. code:: java

    String[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};

    // Java Streams
    boolean x8 = stream(persons).allMatch(c -> c.length() == 5);

    // Java 6 with functional-utils
    boolean x6 = forall(String_.length.andThen(equalTo(5)), persons);

    // Java 8 with functional-utils
    boolean x_ = forall(c -> c.length() == 5, persons);

Challenge 18: Any
-----------------

LINQ :

.. code:: cs

    string[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};
    bool x = persons.Any(c => c.Length == 5);

Java :

.. code:: java

    String[] persons = {"Sam", "Danny", "Jeff", "Erik", "Anders","Derik"};

    // Java Streams
    boolean x8 = stream(persons).anyMatch(c -> c.length() == 5);

    // Java 6 with functional-utils
    boolean x6 = exists(String_.length.andThen(equalTo(5)), persons);

    // Java 8 with functional-utils
    boolean x_ = exists(c -> c.length() == 5, persons);

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

Java :

.. code:: java

    String[] salutations = { "Mr.", "Mrs.", "Ms", "Master" };
    String[] firstNames = { "Samuel", "Jenny", "Joyace", "Sam" };
    String lastName = "McEnzie";

    // Java Streams
    Iterator<String> sal = stream(salutations).iterator();
    stream(firstNames).map(c -> sal.next() + " " + c + " " + lastName)
                      .forEach(System.out::println);

    // Java 6 with functional-utils
    foreach(PrintStream_.println8.ap(System.out),
            map(Tuple_.<String>asList16().andThen(Functional_.mkString1.ap(" ")),
                zip(salutations, firstNames, repeat(lastName))));

    // Java 8 with functional-utils
    foreach(System.out::println, map(c -> c._1 + " " + c._2 + " " + c._3,
                                     zip(salutations, firstNames, repeat(lastName))));
