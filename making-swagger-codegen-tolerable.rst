Making Swagger codegen tolerable
================================

:Abstract: Java client codegen for Swagger doesn't support everything out of the box, but it seems to be extensible.
:Authors: Jyri-Matti Lähteenmäki
:Status: Published
:Date: 2020-04-05

`Swagger Codegen <https://github.com/swagger-api/swagger-codegen>`__ is a library to automatically generate server or client code from a Swagger specification. Many different programming languages are supported. This blog post focuses on Java Client generation. We use version 2.4.2 of swagger-codegen at the time of writing.

The project I'm working on happens to use `Gradle <https://gradle.org>`__, and including the client code generation with a `plugin <https://plugins.gradle.org/plugin/org.hidetake.swagger.generator>`__ was fairly straightforward after we figured out how to make the plugin work (by falling back to version 2.15.0 for now). I assume the codegen part is fine, and the complexities lie within Gradle and its plugin system.

The generation provides quite a few customization options out of the box. However, some features are missing. Here are some of the deficiencies we have encountered. We do some (though not enough!) `dogfooding <https://en.wikipedia.org/wiki/Eating_your_own_dog_food>`__ regarding these tricks with our own APIs (like `Finnish railway infrastructure <https://rata.digitraffic.fi/infra-api/>`__ and its `restrictions <https://rata.digitraffic.fi/jeti-api/>`__), so they *should* be working. Please let me know if you think something is missing from these examples. Also I'd be really happy to learn a better way to do anything we have done, so please let me know.

A better way in the long run would be to study the Swagger Codegen codebase and make appropriate pull requests for these features. Unfortunately I haven't yet found the time for it. If You happen to already know the codebase, I beg you to consider making a pull request instead of using these tricks, but the choice is yours.


1) Typing operation parameters
------------------------------

Let's say your API operation accepts an Interval as a parameter. Instead of handling it as a ``String``, you can override ``io.swagger.codegen.languages.JavaClientCodegen``:

.. code:: java

    public class MyJavaClientCodegen extends JavaClientCodegen {
        @Override
        public CodegenParameter fromParameter(Parameter param, Set<String> imports) {
            CodegenParameter ret = super.fromParameter(param, imports);

            if (ret.paramName.equals("time")) {
                ret.dataType = "Interval";
                ret.datatypeWithEnum = "Interval";
            }
            imports.add("Interval");

            return ret;
        }
    }

I don't know what ``dataType`` and ``dataTypeWithEnum`` fields are or how they differ, so I just set both of them. Also, you have to somehow know when the parameter in question is indeed an interval. If your swagger spec doesn't indicate this in a reasonable way, like in this example, one way is to treat all parameters named ``time`` as intervals.

When you are adding new types, they need to be imported. Add a short name of the type in the ``imports`` collection. Then override another method to map the short name to an actual import clause:

.. code:: java

    public class MyJavaClientCodegen extends JavaClientCodegen {
        @Override
        public void processOpts() {
            super.processOpts();
            importMapping.put("Interval", org.joda.time.Interval.class.getName());
        }
    }

For historical reasons we are using `Joda Time <https://www.joda.org/joda-time/>`__. Please use Java Time API if you can, since it's a lot better.

In addition, we have to provide serialization for our parameter type. Otherwise the library wouldn't know how to transform it into a string. This is done by inheriting the generated ``ApiClient`` class and overriding a method:

.. code:: java

    public class MyApiClient extends ApiClient {
        @Override
        public List<Pair> parameterToPair(String name, Object value) {
            List<Pair> ret = super.parameterToPair(name, value);
            if (value instanceof org.joda.time.Interval) {
                Pair x = Assert.singleton(ret);
                ret = Arrays.asList(new Pair(x.getName(), mySerializeInterval((org.joda.time.Interval)value)));
            }
            return ret;
        }
    }

When you extend the generated ``ApiClient`` class, you might want to change the default client to the inherited one in some appropriate initialization code:

.. code:: java

    myGeneratedClientPackage.Configuration.setDefaultApiClient(new MyApiClient());


2) Typing model properties
--------------------------

Just as you may have an Interval as an operation parameter, you may have it in the returned model. In this case you need to override three methods: First two to add an import clause, and the third one to do the actual thing.

.. code:: java

    public class MyJavaClientCodegen extends JavaClientCodegen {
        @Override
        public void processOpts() {
            super.processOpts();
            importMapping.put("Interval", org.joda.time.Interval.class.getName());
        }

        @Override
        public CodegenModel fromModel(String name, Model model, Map<String, Model> allDefinitions) {
            CodegenModel ret = super.fromModel(name, model, allDefinitions);
            ret.imports.add("Interval");
            return ret;
        }

        @Override
        public CodegenProperty fromProperty(String name, Property p) {
            CodegenProperty ret = super.fromProperty(name, p);
            if (ret.name.equals("validity")) {
                ret.datatype = "Interval";
                ret.datatypeWithEnum = "Interval";
            }
            return ret;
        }
    }

Also here you need a way to recognize which fields are intervals, which I'm here again doing horribly my just looking at the field name.

In addition we need to provide deserialization for our type. Otherwise the library wouldn't know how to transform the JSON value to an instance of our type. This can be done by overriding the generated ``ApiClient`` class and registering a type adapter:

.. code:: java

    public class MyApiClient extends ApiClient {
        public MyApiClient() {
            JSON json = getJSON();
            json.setGson(JSON.createGson()
                .registerTypeAdapter(org.joda.time.Interval.class, new MyIntervalTypeAdapter())
                .create());
        }
    }

If you use something other than GSON, there may be some differences.


3) Optional operation parameters
--------------------------------

Many operation parameters are actually optional. Java doesn't have optional method parameters, so that leaves us with two options: either generate various overloads with different parameter combinations, or generate only one method and handle optionality by passing in nulls.

Swagger-codegen uses the second approach. We can improve upon it by wrapping optional parameters to ``Option``. First we need to import our ``Option`` type:

.. code:: java

    public class MyJavaClientCodegen extends JavaClientCodegen {
        @Override
        public void processOpts() {
            super.processOpts();
            importMapping.put("Option", fi.solita.utils.functional.Option.class.getName());
        }
    }
    
and then wrap the parameter types when needed:

.. code:: java

    public class MyJavaClientCodegen extends JavaClientCodegen {
        @Override
        public CodegenParameter fromParameter(Parameter param, Set<String> imports) {
            CodegenParameter ret = super.fromParameter(param, imports);

            if (!ret.required) {
                imports.add("Option");
                ret.dataType = "Option<" + ret.dataType + ">";
            }

            return ret;
        }
    }

This example is using our own ``Option`` type, but nowadays you should probably be using Java ``Optional``.

Then the unfortunate part: we have to modify the ``api.mustache`` template file to unwrap optional arguments. You can find the template file from ``swagger-codegen`` library from a specific path. In this case it's in ``/Java/libraries/okhttp-gson/api.mustache``. If you are using something else than okhttp, your mileage may vary. Consult the documentation of the tool you are using to invoke swagger-codegen to see how to override templates.

.. code:: java

    public com.squareup.okhttp.Call {{operationId}}Call({{#allParams}}{{{dataType}}} {{paramName}}, {{/allParams}}final ProgressResponseBody.ProgressListener progressListener, final ProgressRequestBody.ProgressRequestListener progressRequestListener) throws ApiException {
        Object {{localVariablePrefix}}localVarPostBody = {{#bodyParam}}{{paramName}}{{/bodyParam}}{{^bodyParam}}null{{/bodyParam}};
        
        // create path and map variables
        String {{localVariablePrefix}}localVarPath = "{{{path}}}"{{#pathParams}}
            .replaceAll("\\{" + "{{baseName}}" + "\\}", {{localVariablePrefix}}apiClient.escapeString({{{paramName}}}.toString())){{/pathParams}};

        {{javaUtilPrefix}}List<Pair> {{localVariablePrefix}}localVarQueryParams = new {{javaUtilPrefix}}ArrayList<Pair>();
        {{javaUtilPrefix}}List<Pair> {{localVariablePrefix}}localVarCollectionQueryParams = new {{javaUtilPrefix}}ArrayList<Pair>();{{#queryParams}}
    -    if ({{paramName}} != null)
    -    {{localVariablePrefix}}{{#collectionFormat}}localVarCollectionQueryParams.addAll({{localVariablePrefix}}apiClient.parameterToPairs("{{{collectionFormat}}}", {{/collectionFormat}}{{^collectionFormat}}localVarQueryParams.addAll({{localVariablePrefix}}apiClient.parameterToPair({{/collectionFormat}}"{{baseName}}", {{paramName}}));{{/queryParams}}
    +    if ({{paramName}}{{#required}} != null{{/required}}{{^required}}.isDefined(){{/required}})
    +    {{localVariablePrefix}}{{#collectionFormat}}localVarCollectionQueryParams.addAll({{localVariablePrefix}}apiClient.parameterToPairs("{{{collectionFormat}}}", {{/collectionFormat}}{{^collectionFormat}}localVarQueryParams.addAll({{localVariablePrefix}}apiClient.parameterToPair({{/collectionFormat}}"{{baseName}}",     {{paramName}}{{^required}}.get(){{/required}}    ));{{/queryParams}}

Unfortunately the template files in swagger-codegen don't seem to be split into small chunks. Maybe there's a good reason for this, I don't know, but it would feel a lot less awkward to override only a small file instead of the whole 300-line operation template.


4) Optional model properties
----------------------------

This is an interesting problem. Due to a bit questionable opinions from highly respected people in the Java community (e.g `Brian Goetz <https://stackoverflow.com/questions/26327957/should-java-8-getters-return-optional-type/26328555#26328555>`__), Java libraries sometimes seem a bit reluctant to use ``Optional`` to improve type safety in certain places. Fortunately many libraries still do.

A relevant `issue <https://github.com/swagger-api/swagger-codegen/issues/2485>`__ has been open since 2016, and based on the discussion, it's quite possible that this will never get implemented or a pull request accepted.

Fortunately, we can wrap properties to ``Option`` with some small code additions and template manipulation. First import ``Option`` to all models:

.. code:: java

    public class MyJavaClientCodegen extends JavaClientCodegen {
        @Override
        public void processOpts() {
            super.processOpts();
            importMapping.put("Option", fi.solita.utils.functional.Option.class.getName());
        }

        @Override
        public CodegenModel fromModel(String name, Model model, Map<String, Model> allDefinitions) {
            CodegenModel ret = super.fromModel(name, model, allDefinitions);
            ret.imports.add("Option");
            return ret;
        }
    }

Then the ugly part: we need another template override. This can be found in ``/Java/pojo.mustache``. Again, it would be much nicer to override a bunch of smaller template files:

.. code:: java

    @@ -60,10 +60,10 @@
       @SerializedName("{{baseName}}")
       {{/gson}}
       {{#isContainer}}
    -  private {{^required}}Option<{{/required}}{{{datatypeWithEnum}}}{{^required}}>{{/required}} {{name}}{{#required}} = {{{defaultValue}}}{{/required}}{{^required}} = null{{/required}};
    +  private {{^required}}Option<{{/required}}{{{datatypeWithEnum}}}{{^required}}>{{/required}} {{name}}{{#required}} = {{{defaultValue}}}{{/required}}{{^required}} = Option.None(){{/required}};
       {{/isContainer}}
       {{^isContainer}}
    -  private {{^required}}Option<{{/required}}{{{datatypeWithEnum}}}{{^required}}>{{/required}} {{name}} = {{{defaultValue}}};
    +  private {{^required}}Option<{{/required}}{{{datatypeWithEnum}}}{{^required}}>{{/required}} {{name}}{{#required}} = {{{defaultValue}}}{{/required}}{{^required}} = Option.None(){{/required}};
       {{/isContainer}}
     
       {{/vars}}
    
    @@ -91,7 +91,7 @@
       {{#vars}}
       {{^isReadOnly}}
       public {{classname}} {{name}}({{{datatypeWithEnum}}} {{name}}) {
    -    this.{{name}} = {{name}};
    +    this.{{name}} = {{^required}}Option.of({{/required}}{{name}}{{^required}}){{/required}};
         return this;
       }
       {{#isListContainer}}
    
    @@ -99,10 +99,13 @@
       public {{classname}} add{{nameInCamelCase}}Item({{{items.datatypeWithEnum}}} {{name}}Item) {
         {{^required}}
         if (this.{{name}} == null) {
    -      this.{{name}} = {{{defaultValue}}};
    +      this.{{name}} = {{^required}}Option.of({{/required}}{{{defaultValue}}}{{^required}}){{/required}};
         }
    +    this.{{name}}.get().add({{name}}Item);
         {{/required}}
    +    {{#required}}
         this.{{name}}.add({{name}}Item);
    +    {{/required}}
         return this;
       }
       {{/isListContainer}}
    
    @@ -139,13 +142,13 @@
     {{#vendorExtensions.extraAnnotation}}
       {{{vendorExtensions.extraAnnotation}}}
     {{/vendorExtensions.extraAnnotation}}
    -  public {{{datatypeWithEnum}}} {{#isBoolean}}is{{/isBoolean}}{{getter}}() {
    +  public {{^required}}Option<{{/required}}{{{datatypeWithEnum}}}{{^required}}>{{/required}} {{#isBoolean}}is{{/isBoolean}}{{getter}}() {
         return {{name}};
       }
       {{^isReadOnly}}
     
       public void {{setter}}({{{datatypeWithEnum}}} {{name}}) {
    -    this.{{name}} = {{name}};
    +    this.{{name}} = {{^required}}Option.of({{/required}}{{name}}{{^required}}){{/required}};
       }
       {{/isReadOnly}}

5) Removing an operation parameter
----------------------------------

Sometimes the code generator might include parameters that aren't actually interesting. For example in our case the operations always include ``format`` parameter since we like to use URI file extension to indicate the output format. When invoking operations from the generated client, however, the format is always JSON (or something else that we don't care about at this level). To remove a parameter, override another method:

.. code:: java

    public class MyJavaClientCodegen extends JavaClientCodegen {
        @Override
        public CodegenOperation fromOperation(String path, String httpMethod, Operation operation, Map<String, Model> definitions, Swagger swagger) {
            CodegenOperation ret = super.fromOperation(path, httpMethod, operation, definitions, swagger);
            ret.allParams.removeIf(x -> x.paramName.equals("format"));
            if (!ret.allParams.isEmpty()) {
                ret.allParams.get(ret.allParams.size()-1).hasMore = false;
            }
            for (CodegenParameter param: ret.pathParams) {
                if (param.paramName.equals("format")) {
                    param.paramName = "\"json\"";
                }
            }
            return ret;
        }
    }

The code generator seems to have some earlier populated state indicating which parameter is the last one, so we have to update that state here.

Since in this case the parameter is still required to generate the operation URI, we cannot completely remove it. Instead, we can change its name here to a constant string. I hope there's a more elegant way to do this, that I'm just not aware of yet...

Conclusion
----------

Already when I started my "professional" career as a software designer somewhere around 2006, XML technologies allowed us to generate API specification from program code, and generate client code from that specification. During the past decade, the JSON world has slowly been catching up, and now we are again able to mostly ignore the concrete serialization format, and concentrate on the API as operations and data.

Although I only have experience of the Java client generation, Swagger-codegen seems to work and seems to even be extensible to handle edge cases. I seriously recommend everyone to use it. Please generate your client code: don't operate directly on JSON strings or manually write client structures.