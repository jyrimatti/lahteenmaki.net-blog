Making Jackson tolerable
========================

:Authors: Jyri-Matti Lähteenmäki
:Status: Draft

I believe that the "right way" to do serialization/deserialization is a
"type class based" approach. Unfortunately the community hasn't given us
one in the Java-land. The good thing with
`Jackson <http://wiki.fasterxml.com/JacksonHome>`__ is that it provides
ways to make it more tolerable.

1) Serializes all classes
-------------------------

By default all classes are serialized using some default behavior. This
is silly. I would like to explicitly define how specific classes are
serialized, and get an error if I forget one. Automatic
best-effort-serialization should be an opt-in.

Also, for many projects it would be valuable to be able to see in the
code which classes are possibly serialized. For example, I would
never-ever want a Hibernate Entity or a MySecretUserDetails to be
serialized. Prohibiting serialization should be the default, not opt-in.

This is how you can make Jackson serialize only classes that you have
explicitly provided a serializer, or have marked with an annotation
allowing automatic bean serialization:

In your ``com.fasterxml.jackson.databind.ObjectMapper`` define a new
``com.fasterxml.jackson.databind.ser.BeanSerializerFactory`` with an
overridden method:

.. code:: java

    @Override
    public JsonSerializer<Object> createSerializer(SerializerProvider prov, JavaType origType) throws JsonMappingException {
        JsonSerializer<Object> candidate = super.createSerializer(prov, origType);
        if (candidate instanceof BeanSerializer &&
            !origType.getRawClass().isAnnotationPresent(YesIAmAllowingAutomaticSerialization.class)) {
          throw new RuntimeException();
        }
        return candidate;
    }

This will fail with an exception every time Jackson tries to use
``BeanSerializer``.

Similar hack can be used for deserialization. You can register it with
something like this:

.. code:: java

    setSerializerFactory(new CustomBeanSerializerFactory(BeanSerializerFactory.instance.getFactoryConfig()));

You should probably also override this on your ObjectMapper to fail
early:

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

Jackson uses separate serializers for Map keys. I don't know why, but
I'm guessing this is due to the serializers not being pure functions but
instead writing directly to some output. Probably performance reasons,
the mother of all failures. If no suitable serializer for a key is
found, a toString serializer is used instead. That's just silly.

Like with regular serialization, explicit definition of keyserializers
should be required by default. A toString behaviour could be an opt-in.

You can make Jackson fail when no suitable keyserializer is found by
overriding the following method from you ``BeanSerializerFactory``:

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

Yes, it's horrendously ugly. Please leave a better alternative to the
comments.

3) Deserializes to nulls
------------------------

If a value is not present on deserialization, Jackson leaves the
corresponding field null. Using nulls is always a catastrofic mistake.
All projects should use an Optional of some kind, self-written or
whatever.

This is how you can make Jackson deserialize to your custom generic
Option type:

Make a custom
``com.fasterxml.jackson.databind.deser.Deserializers.Base`` and override
the following method:

.. code:: java

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

Register it in your ``Module``:

.. code:: java

    context.addDeserializers(new MyCustomDeserializersBase());

4) Requires getters/setters
---------------------------

By default Jackson serializes "Java Bean Properties". That is, getters.
Java Beans seems to be one of the most harmful standards in the Java
ecosystem.

Jackson should not serialize arbitrary methods by default. It is *data*
that is serialized, so public fields would be a good default.
Serializing anything other than "public data" should be explicit.

This is how you can make Jackson ignore methods and only serialize
public fields. In your ``ObjectMapper``:

.. code:: java

    configure(MapperFeature.AUTO_DETECT_GETTERS, false);
    configure(MapperFeature.AUTO_DETECT_IS_GETTERS, false);
    configure(MapperFeature.AUTO_DETECT_SETTERS, false);

5) Has odd default deserialization behavior
-------------------------------------------

By default Jackson is fine with missing values for primitive fields.
This is odd, since a primitive (versus an object) clearly indicates a
required value. Jackson also accepts numbers for Enum values, which is
just nasty.

Jackson should, by default, fail when required fields are missing and
only accept explicit (or at least sensible) deserialization for enums.

This is how you can fix these issues. In your ``ObjectMapper``:

.. code:: java

    configure(DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES, true);
    configure(DeserializationFeature.FAIL_ON_NUMBERS_FOR_ENUMS, true);

6) Has dangerous default serializers
------------------------------------

Serialization definitions should be explicit. That doesn't mean it
should be difficult or verbose to use a serialization library, just a
few lines of code include needed serializers.

Jackson doesn't even seem to have a configuration option to disable
default serializers, but this is how you can do it. In your custom
``BeanSerializerFactory`` override the following method:

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

Same thing as with serializers. Create a custom
``com.fasterxml.jackson.databind.deser.BeanDeserializerFactory`` and
override the following method:

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

8) Static serialization behavior
--------------------------------

I guess. What I mean is, that since serialization behavior is controlled
through configuring the ObjectMapper or adding annotations, it cannot be
configured by use case. For examples, if most of the time I would like
to serialize a whole class, how could I sometimes omit one ore more
fields? If the serializer could be given to serialization procedure as a
parameter I could use different variants, but now my only option seems
to be to create huge amounts of new classes.

Since I don't want to use nulls anywhere (except serialize/deserialize a
missing Optional to/from json-null) I can set a Jackson feature to
exclude nulls from serialization. In your ``ObjectMapper``:

.. code:: java

    setSerializationInclusion(Include.NON_NULL);

This way I can omit fields by setting them to null. Took me a while to
discover this feature. Sensible default behavior would probably be to
raise an error if a null is encountered in serialization, and add a hint
of this feature to the error message.

Conclusion
----------

Jackson is "a wrong solution to the problem", but one can live with it.

Still some problems remain:

1. How can I make Jackson fail if there's a value missing for a field on
   deserialization?
2. Could key serializers somehow be combined with the regular ones?
