; (preproc_include) @symbol

; #include "user.h"
(preproc_include
  (string_literal
    (string_content) @name) (#set! "kind" "File")) @symbol

; #include <math.h>
(preproc_include
  (system_lib_string) @name (#set! "kind" "File")) @symbol

; import std;
(import_declaration
  name: (module_name
    (identifier) @name) (#set! "kind" "Module")) @symbol

; import <iostream>;
(import_declaration
  (system_lib_string) @name (#set! "kind" "Module")) @symbol
