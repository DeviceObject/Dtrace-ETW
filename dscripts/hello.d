/* hello.d -- A simple D program that uses the BEGIN probe */

#pragma D option quiet
BEGIN
{
 
  printf("%s %d\n", "Hello World", timestamp);
  exit(0);
}

END
{
  trace("goodbye, world");
}