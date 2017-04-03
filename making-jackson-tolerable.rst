Making Jackson tolerable
========================

:Abstract: I believe the "right way" to do serialization and deserialization is a "type class based" approach, like what Aeson does. Unfortunately the community hasn't given us one in the Java-land. Jackson is a widely (?) used JSON serialization libary. Unfortunately it has a few problems, but the good thing is that it provides some ways to make it more tolerable.
:Authors: Jyri-Matti Lähteenmäki
:Status: Published
:Date: 2017-04-03

I believe the "right way" to do serialization and deserialization is a "type class based" approach, like what `Aeson <https://github.com/bos/aeson>`__ does. Unfortunately the community hasn't given us one in the Java-land.

`Jackson <http://wiki.fasterxml.com/JacksonHome>`__ is a widely (?) used JSON serialization libary. Unfortunately it has a few problems, but the good thing is that it provides some ways to make it more tolerable:

1) Serializes all classes
-------------------------

By default all classes are serialized using some default behavior. This is unfortunate. I would like to explicitly define how specific classes are serialized, and get an error if I forget one. Automatic best-effort-serialization should be an opt-in.

For many projects it would be valuable to be able to see in the code which classes are possibly serialized. For example, I would never-ever want a Hibernate Entity or a MySecretUserDetails to be serialized. Prohibiting serialization should be the default, not opt-in.

This is how you can make Jackson serialize only classes that you have explicitly provided a serializer, or have marked with an annotation allowing automatic bean serialization:

In your ``com.fasterxml.jackson.databind.ObjectMapper`` define a new ``com.fasterxml.jackson.databind.ser.BeanSerializerFactory`` with an overridden method:

.. code:: java

  @Override
  public JsonSerializer<Object> createSerializer(SerializerProvider prov, JavaType origType) throws JsonMappingException {
    JsonSerializer<Object> candidate = super.createSerializer(prov, origType);
    if (candidate instanceof BeanSerializer && !origType.getRawClass().isAnnotationPresent(YesIAmAllowingAutomaticSerialization.class)) {
      throw new RuntimeException();
    }
    return candidate;
  }

This will fail with an exception every time Jackson tries to use ``BeanSerializer``. Similar hack can be used for deserialization.

You can register it with something like this:

.. code:: java

  setSerializerFactory(new CustomBeanSerializerFactory(BeanSerializerFactory.instance.getFactoryConfig()));

You should probably also override this on your ObjectMapper to fail early:

.. code:: java

  @Override
  public boolean canSerialize(Class<?> type) {
      if (!super.canSerialize(type)) {
          throw new RuntimeException();
      }
      return true;
  }

2) Serializes Map keys with toString()
--------------------------------------

Jackson uses separate serializers for Map keys. I don't know why, but I'm guessing this is due to the serializers not being pure functions but instead writing directly to some output. Probably performance reasons, the mother of all failures. If no suitable serializer for a key is found, a toString serializer is used instead. That's annoying.

Explicit definition of keyserializers should be required by default. A fallback-to-toString behaviour could be an opt-in.

You can make Jackson fail when no suitable keyserializer is found by overriding the following method from you ``BeanSerializerFactory``:

.. code:: java

  @Override
  public JsonSerializer<Object> createKeySerializer(final SerializationConfig config, JavaType type) {
    JsonSerializer<Object> serializer = super.createKeySerializer(config, type);
    if (serializer == null) {
      return new StdSerializer<Object>((Class<Object>)type.getRawClass()) {
        @Override
        public void serialize(Object value, JsonGenerator jgen, SerializerProvider provider) throws IOException, JsonGenerationException {
          JsonSerializer<Object> ser = createKeySerializer(config, SimpleType.construct(value.getClass()));
          if (value.getClass() == String.class) {
            ser = new StdKeySerializer();
          } else if (ser == null || ser.getClass() == this.getClass()) {
            throw new RuntimeException();
          }
          ser.serialize(value, jgen, provider);
        }
      };
    }
    return serializer;
  }

The point is to return something else than ``null`` to prevent default behavior, but to throw an exception if the returned serializer is actually used. At this point the real value is known, so we can still try to find a suitable serializer and accept Strings.

Yes, it's horrendously ugly. Please leave a better alternative to the comments.

3) Deserializes to nulls
------------------------

If a value is not present on deserialization, Jackson leaves the corresponding field null. Using nulls is always a catastrofic mistake. All projects should use an Optional/Option/Maybe of some kind, self-written or whatever.

This is how you can make Jackson deserialize to your custom generic Option type:

Make a custom ``com.fasterxml.jackson.databind.deser.Deserializers.Base`` and override the following method:

.. code:: java

  public class MyCustomDeserializersBase extends Deserializers.Base {
    @Override
    public JsonDeserializer<?> findBeanDeserializer(final JavaType type, DeserializationConfig config, BeanDescription beanDesc) throws JsonMappingException {
      if (type.getRawClass() == Option.class) {
        return new StdDeserializer<Option<?>>(type) {
          @Override
          public Option<?> deserialize(JsonParser jp, DeserializationContext ctxt) throws IOException, JsonProcessingException {
            JsonDeserializer<?> valueDeser = findDeserializer(ctxt, type.containedType(0), null);
            if (jp.getCurrentToken() == JsonToken.VALUE_NULL) {
              return Option.None();
            }
            // Option.of returns None for a null:
            return Option.of(valueDeser.deserialize(jp, ctxt));
          }

          @Override
          public Option<?> getNullValue() {
            return Option.None();
          }
        };
      }
    }
  }

Register it in your ``Modules``:

.. code:: java

  @Override
  public void setupModule(SetupContext context) {
    super.setupModule(context);
    context.addDeserializers(new MyCustomDeserializersBase());
  }

I don't know of a nicer way to do this. Please write an improvement to the comments!

4) Requires getters/setters
---------------------------

By default Jackson serializes "Java Bean Properties". That is, getters. Java Beans is one of the most harmful standards in the Java ecosystem.

Jackson should not serialize arbitrary methods by default. It is *data* that is serialized, so public fields would be a good default. Serializing anything other than "public data" should be explicit. Your opinion may vary on this one, but hopefully we agree that we should be explicit with our choice.

This is how you can make Jackson ignore methods and only serialize public fields. In your ``ObjectMapper``:

.. code:: java

  configure(MapperFeature.AUTO_DETECT_GETTERS, false);
  configure(MapperFeature.AUTO_DETECT_IS_GETTERS, false);
  configure(MapperFeature.AUTO_DETECT_SETTERS, false);

5) Has weird default deserialization behavior
-------------------------------------------

By default Jackson is fine with missing values for primitive fields. This is odd, since a primitive (versus an object) clearly indicates a required value. Jackson also accepts numbers for Enum values, which is just nasty.

Jackson should, by default, fail when required fields are missing and only accept explicit (or at least sensible) deserialization for enums.

This is how you can fix these issues. In your ``ObjectMapper``:

.. code:: java

  configure(DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES, true);
  configure(DeserializationFeature.FAIL_ON_NUMBERS_FOR_ENUMS, true);

It feels weird to me that these are already easily configurable, but the defaults are wrong.

6) Has dangerous default serializers
------------------------------------

Serialization definitions should be explicit. That doesn't mean it should be difficult or verbose to use a serialization library. The library could include the same default serializers, and provide documentation about the one-liner to enable them.

Jackson doesn't even seem to have a configuration option to disable default serializers, but this is how you can do it. In your custom ``BeanSerializerFactory`` override the following method:

.. code:: java

  @Override
  public JsonSerializer<Object> createSerializer(SerializerProvider prov, JavaType origType) throws JsonMappingException {
    JsonSerializer<?> candidate = super.createSerializer(prov, origType);
    if (candidate instanceof EnumSerializer) {
      throw new RuntimeException();
    } else if (candidate instanceof CalendarSerializer) {
      throw new RuntimeException();
    } else if (candidate instanceof DateSerializer) {
      throw new RuntimeException();
    } else if (candidate instanceof SqlTimeSerializer) {
      throw new RuntimeException();
    } else if (candidate instanceof SqlDateSerializer) {
      throw new RuntimeException();
    }
    return (JsonSerializer<Object>) candidate;
  }

7) Has dangerous default deserializers
--------------------------------------

Same thing as with serializers. Create a custom ``com.fasterxml.jackson.databind.deser.BeanDeserializerFactory`` and override the following method:

.. code:: java

  @Override
  public JsonDeserializer<Object> createBeanDeserializer(DeserializationContext ctxt, JavaType type, BeanDescription beanDesc) throws JsonMappingException {
    JsonDeserializer<?> candidate = super.createBeanDeserializer(ctxt, type, beanDesc);
    if (candidate instanceof CalendarDeserializer) {
      throw new RuntimeException();
    } else if (candidate instanceof DateDeserializer) {
      throw new RuntimeException();
    } else if (candidate instanceof TimestampDeserializer) {
      throw new RuntimeException();
    } else if (candidate instanceof SqlDateDeserializer) {
      throw new RuntimeException();
    }
    return (JsonDeserializer<Object>) candidate;
  }

For enums we have to override another method:

.. code:: java

  @Override
  public JsonDeserializer<?> createEnumDeserializer(DeserializationContext ctxt, JavaType type, BeanDescription beanDesc) throws JsonMappingException {
    JsonDeserializer<?> candidate = super.createEnumDeserializer(ctxt, type, beanDesc);
    if (candidate instanceof EnumDeserializer) {
      throw new RuntimeException();
    }
    return candidate;
  }

In the if-clause you can check for the existence of a particular annotation if you want to allow default serialization behavior of an enumeration.

8) Static serialization behavior
--------------------------------

Since serialization behavior is controlled through configuring the ObjectMapper or adding annotations, it cannot be configured by use case. For examples, if most of the time I would like to serialize a whole class, how could I sometimes omit one ore more fields? If the serializer could be given to serialization procedure as a parameter I could use different variants, but now my only option seems to be to create huge amounts of new classes.

Since I don't want to use nulls anywhere, I can set a Jackson feature to exclude nulls from serialization. In your ``ObjectMapper``:

.. code:: java

  setSerializationInclusion(Include.NON_NULL);

This way I can omit fields by setting them to null. Took me a while to discover this feature. Sensible default behavior would probably be to raise an error if a null is encountered in serialization, and add a hint of this feature to the error message.

9) Deserialization doesn't fail with missing data

We already saw how Jackson can be made to fail on missing primitive values, but since optionality should be described with an Option type, Jackson should also fail on missing object values.

This is how you can do it. Register a ``BeanDeserializationModifier`` in your ``Modules``:

.. code:: java

  @Override
  public void setupModule(SetupContext context) {
    super.setupModule(context);
    context.addBeanDeserializerModifier(new BeanDeserializerModifier() {
        @Override
        public JsonDeserializer<?> modifyDeserializer(DeserializationConfig config, BeanDescription beanDesc, JsonDeserializer<?> deserializer) {
          return new Delegater(super.modifyDeserializer(config, beanDesc, deserializer));
        }
    });
  }

.. code:: java

  private class Delegater extends DelegatingDeserializer {
    public Delegater(JsonDeserializer<?> delegatee) {
      super(delegatee);
    }

    @Override
    protected JsonDeserializer<?> newDelegatingInstance(JsonDeserializer<?> newDelegatee) {
      return new Delegater(newDelegatee);
    }

    @Override
    public Object deserialize(JsonParser jp, DeserializationContext ctxt) throws IOException, JsonProcessingException {
      Object ret = super.deserialize(jp, ctxt);
      for (Field f: declaredFieldsIncludingSuperClasses(ret.getClass())) {
        try {
          f.setAccessible(true);
          if (f.get(ret) == null) {
            if (Option.class.isAssignableFrom(f.getType())) {
              // set missing Option:s to None()
              f.set(ret, Option.None());
            } else {
              throw new RuntimeException("Missing field: " + f.getName());
            }
          }
        } catch (IllegalAccessException e) {
          throw new RuntimeException(e);
        }
      }
      return ret;
    }
  }

So the trick is to check for null fields after deserialization has occured. Optional fields can and should be assigned an Option.None value so that the resulting instance contains no nulls.

Conclusion
----------

Jackson is *a wrong solution to the problem of json serialization and deserialization*, but one can live with it.

Still some problems remain:

1. Could key serializers somehow be combined with the regular ones?
2. Anything *you* have encountered? Please let me know in the comments!
