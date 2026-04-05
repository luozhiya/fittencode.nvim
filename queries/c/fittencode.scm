; #include "user.h"
(preproc_include
  (string_literal
    (string_content) @name) (#set! "kind" "File")) @symbol

; #include <math.h>
(preproc_include
  (system_lib_string) @name (#set! "kind" "File")) @symbol
