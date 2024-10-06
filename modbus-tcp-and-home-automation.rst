Modbus TCP and home automation
==============================

:Abstract: Modbus TCP can be used to read and control some devices at home
:Authors: Jyri-Matti Lähteenmäki
:Date: 2024-10-06
:Status: Published

I have some home automation hobbies, and I've been using Modbus TCP to read and control some devices. This is a short introduction to Modbus TCP and how I've used it at home.

What is Modbus?
---------------

.. epigraph::

    It is a de facto standard, truly open and the most widely used network protocol in the industrial manufacturing environment.
    
    -- `https://modbus.org<https://modbus.org/faq.php>`_

Modbus is a bit oldish messaging structure developed by Modicon in 1979. It can be used to read and write data sources categorized as a few different types:

- Discrete input:   1bit,       read-only
- Coil:             1bit,       read/write
- Input register:   16bit word, read-only
- Holding register: 16bit word, read/write
- Files:                        read/write

Modbus can support different data types but unfortunately they are not standardized, not even `endianness<https://en.wikipedia.org/wiki/Endianness>`_. The manufacturer can decide what to put in the 16bit register, or if multiple consecutive registers form a single piece of data, and how the data should be decoded.

Different physical transmission mediums are supported, but `Modbus RTU <https://en.wikipedia.org/wiki/Modbus#Modbus_RTU>`_ over `RS-485 <https://en.wikipedia.org/wiki/RS-485>`_ is probably the most common. You could use a `RaspberryPI<https://www.raspberrypi.com>`_ / `Arduino<https://www.arduino.cc>`_ for implementation, but it gets a bit complicated. Much too complicated for me!


Easier solution?
----------------

`Modbus TCP<https://modbus.org/docs/Modbus_Messaging_Implementation_Guide_V1_0b.pdf>`_ was published in 1999. It publishes Modbus over regular `Ethernet<https://en.wikipedia.org/wiki/Ethernet>`_ with `TCP/IP<https://en.wikipedia.org/wiki/Transmission_Control_Protocol>`_, and I believe it is often implemeted as a simple proxy device. This is much easier than a *bus*, since collisions etc are handled by Ethernet layer and error correction is handled by TCP.

Another thing that makes this even too easy is that for some reason there is no authentication whatsoever. I don't know why, but I'm not complaining. Maybe in 1999 networks were mostly still considered to be wired and physically inaccessible, though obviously nowadays you can wirelessly connect into almost any network and all networks are connected.

Modbus TCP has a well defined frame structure. It's good they didn't continue the "let manufacturer specify everything" tradition, though unfortunately we are only talking about transmission medium here. Data types and semantics remain undefined.

Usually port 502 is used for communication. Not necessarily though, for example my Huawei solar inverter uses 502 for the normal Modbus TCP interface, but has an additional admin interface in another port behind another network. According to Internet they have also changed the port at least once.

Unfortunately Modbus doesn't define any always existing registers that could be used for Hello-world, so you have to have some documentation or do some guesswork. If you don't have appropriate documentation you can always use a port scan to at least find all the ports that are responding, with something like:

.. code:: bash

    > nc -vz <device-address> 1-99999


Modbus TCP frame (ADU - Application Data Unit)
----------------------------------------------

The Modbus TCP frame consists of two parts: MBAP header and PDU (Protocol Data Unit). Here's an example frame for reading register values:

.. code:: bash
    
    MBAP header
    --------------------      PDU
                         --------------
    f9 e9 00 00 00 06 ff 03 9c 41 00 02
    ----- Transaction Identifier
          ----- Protocol Identifier
                ----- Length
                      -- Unit Identifier

                         -- function code
                            ----- Register start address
                                  ----- Number of registers

*Transaction Identifier* can be used to connect a response to a request. Since TCP is already a connection oriented client-server protocol, I guess you will only need this if you are sending multiple commands using the same connection and without waiting for a response in between.

*Protocol Identifier* is always 0. *Length* gives the amount of bytes following it. This may vary depending on the function code and the length of data sent/received.

*Unit Identifier* is the identifier of the target device. Due to connection oriented TCP this would generally not be needed, but I guess it might be relevant if the device happens to have sub devices of some kind that you can individually communicate with. On the other hand, a device might require the correct id even if it's irrelevant, like Huawei always requires identifier 100.

*Function code* is the requested operation. It is followed by the actual payload, for example the first register address and amount of registers to read. These obviously depend on the function code.

Most common operations (function codes):

1. Read Coil
2. Read Discrete Input
3. Read Holding Register
4. Read Input Register
5. Write Single Coil
6. Write Single Register

While for anything violating the specification the most common action seems to be just to silently fail, Modbus does define an exception behavior for some common errors. For example a request for a non-existing register would result in a response with function code + 0x80 and an exception code telling the reason for the error (0x02 - "Illegal Data Address").


My home
-------

`Stiebel Eltron<https://www.stiebel-eltron.com/>`_ has `good documentation<https://www.stiebel-eltron.com.au/download/1685919441_321798-44755-9770_ISG%20Modbus_en.pdf>`_ of available registers, their semantics and data types. There are four different data types with different value space. Data types also have a specific multiplier that needs to be used for reading and writing.

Documented registers are off-by-one for some reason. This offset is documented, though, so not a big problem. For some reason not everything can be control through Modbus TCP, and I still have to resort to parsing and submitting HTML forms for some things.

My code for interfacing with Stiebel is in `Github<https://github.com/jyrimatti/stiebel/>`_.

`Huawei<https://www.huawei.com/>`_ has only brief documentation having  a couple of useless registers. The most important ones like total produced yield are missing from the documentation, but luckily they could be guessed when you know the actual value from the Huawei mobile app.

Tech support answered my questions and told me about the required unit identifier as well as a cunning trap that the inverter won't answer anything unless you wait about a second between opening the TCP connection and sending the command. They didn't however tell me about additional registers even when I asked.

My code for interfacing with Huawei is in `Github<https://github.com/jyrimatti/huawei/>`_.


Tools
-----

So how to interface with Modbus TCP? I would of course use command line tools to integrate these to a home automation platform.

I first used `Modbus CLI<https://github.com/favalex/modbus-cli>`_ but it had some issues. First of all, it's written in `Python<https://www.python.org>`_ and thus has a startup-overhead of some hundreds of milliseconds (at least on a RaspberryPI with some load). Not suitable for real-time stateless use where reading each of maybe tens of values is performed in its own process invocation. Also, it didn't support a delay between opening connection and sending request, so it didn't work with Huawei.

If you still want to try it out, just install it in whichever way you prefer to install Python stuff. My choice would be to use `Nix<https://nixos.org>`_:

.. code:: bash

    > cat modbus_cli.nix 
    { python3Packages }:
    with python3Packages;
    buildPythonPackage rec {
        pname = "modbus_cli";
        version = "0.1.9";
        src = fetchPypi {
            inherit pname version;
            sha256 = "sha256-81mmeP3qXcUqnnNK33w1M2esfh9lQrdT3ydb1O+UUdw=";
        };
        propagatedBuildInputs = [ colorama umodbus ];
    }
    > nix-shell -p "pkgs.callPackage ./modbus_cli.nix {}"

After having the tool, you can use it like this:

.. code:: bash

    # outside temperature is register 507 (off-by-one) having a multiplier of 0.1

    > modbus <ip-address> i@506
    Parsed 0 registers definitions from 1 files
    506: 113 0x71

    > modbus -v <ip-address> i@506
    Parsed 0 registers definitions from 1 files
    → < 11 6f 00 00 00 06 ff 04 01 fa 00 01 >
    ← < 11 6f 00 00 00 05 ff 04 02 00 71 > 11 bytes
    ← [113]
    506: 113 0x71


I have a tendency to sometimes write stuff myself, since I'm a software developer. Instead of finally learning `Rust<https://www.rust-lang.org>`_ I eventually decided to write just another quick-and-dirty shell script which I call `modbus.sh<https://github.com/jyrimatti/modbus.sh>`_. At least it's so low-level that all kinds of debugging should be easy, and I even managed to put in some data type handling.

You can use it like this:

.. code:: bash

    > git clone https://github.com/jyrimatti/modbus.sh
    > cd modbus.sh
    > ./modbus.sh --help

    # Stiebel outside temperature
    > ./modbus.sh -m 0.1 <ip-address> 4 506 int16
    11.3

    # Huawei total yield
    > ./modbus.sh -m 10 -d 1 -u 100 <ip-address> 3 37514 uint32
    6107980


Conclusion
----------

Despite of its age, Modbus TCP is an efficient and working solution to manage home automation. There's no need for low quality and unreliable manufacturer cloud services, or even an internet connection. Unfortunately due to insufficient standardisation, good documentation from the device manufacturer is a necessity.

Since there's no authentication, if you have a device that understands Modbus TCP, think twice before opening your local network to the Internet. On the other hand, any vulnerable/smart device you already have can theoretically provide remote access to your internal network, so you can consider the game already lost and just make your home automation life as painless as possible :)
