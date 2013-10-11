UrEmbed
-------

Embeds file(s) into the Ur/Web project by creating the module containing

    datatype content = File_A | File_B ...
    val binary : content -> transaction blob

Additionally, Urembed greatly simplifies writing of the JavaScript FFIs.

Installation
------------

You will need [Haskell platform](http://www.haskell.org/platform/) and several
additional packages. Also, POSIX environment is required (Cygwin should suffice
under Windows)

    $ git clone https://github.com/grwlf/urembed
    $ cd urembed
    $ cabal configure
    $ cabal build
    $ cabal install

Usage
-----

    $ urembed --help
    UrEmebed is the Ur/Web module generator

    Usage: urembed [-o|--output FILE.urp] [--version] [FILE]
      
      Converts a set of FILEs into the Ur/Web modules. Each Module will contain
      following functions:

        val binary : unit -> transaction blob
        val blobpage : unit -> transaction page
        val text : unit -> transaction string

        Additionally, FFI signatures will be provided for JavaScript files. In order
        to enable this, you have to name your JS functions using the name__type
        scheme. See README for details. Also, uru project uses this a lot.

        (NOTE: the interface is not stable. Pleas, fork the Urembed sources
        before using)

      The master project (specified with -o FILE.urp) will contain a dictionary
      version of those functions taking the datatype key as an argument, instead of
      unit. In order to actually compile the binaries, you have to call

        make -f FILE.mk CC=.. LD=.. UR_INCLUDE_DIR=.. urp

      Where FILE.mk is the Makefile, generated by urembed.

        Example: urembed -o static/Static.urp Style.css Script.js
                 make -C static -f Static.mk CC=gcc LD=ld UR_INCLUDE_DIR=/usr/local/include/urweb urp

      Note: output directory should exist


    Available options:
      -h,--help                Show this help text
      -o,--output FILE.urp     Name of the Ur/Web project being generated
      --version                Show version information
      FILE                     File to embed


### Example

To embed Style.css into ypur Ur/Web project:

    1. Run urembed

        $ urembed -o lib/autogen/Static.urp Style.css

        Static.urp.in will be generated as well as Static.mk describing the rules
        to build all the binaries

    2. Run make to build Static.urp

        $ make -C lib/autogen -f Static.mk urp

    3. Include Static.urp into your master .urp file.

        # App.urp
        ...
        library lib/autogen/Static
        ...

    4. Use the functionality. In this case, lets ship Style.css to the user


        # App.ur

        (* Direct call *)
        fun serve_css a =
          b <- Static.binary Static.Style_css;
          returnBlob b (blessMime "text/css")

        (* Using a dictionary wrappers *)
        fun style2 {} = Static.blobpage Static.Style_css

### JavaScript FFI helper

Urembed is able to bind top-level JavaScript functions via
JavaScript FFI. In order to do it, user has to make sure that FILE has .js
extension and contains top-level functions named according to the 'name\_\_type'
format. For example:
    
    # FILE.js
    function init__unit(menustyle__css_class, text__string) {}

    will be translated into Ur/Web's function

    # FILE.urs
    val init : css_class -> string -> transaction unit

Also, it is allowed to drop the name\_\_ part for argument names, so this is
also legal

    # FILE.js
    function init__unit(css_class, string) {}

    results in

    # FILE.urs
    val init : css_class -> string -> transaction unit
  

Next, the pure\_ prefix in type name will instruct urembed to declare pure
function (without 'transaction' part)

    # FILE.js
    function init__pure_string(css_class, string) {}

    results in

    # FILE.urs
    val init : css_class -> string -> string

Finally, sometimes users want to declare their own types. Here is how to do it
with Urembed:

    # FILE.js

    // Dummy javascript variable, just to set type name
    var type__tmce_imglist;

    function imglist_new__tmce_imglist( unit ) {
      return [];
    }

    function imglist_insert__tmce_imglist(string, url, tmce_imglist) {
      return tmce_imglist.concat([{title:string, value:url}]);
    }

    # FILE.urs
    type tmce_imglist
    val imglist_new : unit -> transaction tmce_imglist
    val imglist_insert : string -> url -> tmce_imglist -> transaction tmce_imglist

