// RUN: %boogie -infer:j -instrumentInfer:e -printInstrumented -noVerify %s > %t
// RUN: %diff %s.expect %t
// Simple test file for checking the inference of linear constraints.

var x: int;
var y: int;

procedure p()
  modifies x;
{
  A:
    assume x < y;
    goto B, C;
  B:
    x := x*x;
    return;
  C:
    return;
}
