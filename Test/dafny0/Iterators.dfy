iterator MyIter<T>(q: T) yields (x: T, y: T)
{
}

iterator MyIntIter() yields (x: int, y: int)
{
  x, y := 0, 0;
  yield;
  yield 2, 3;
  x, y := y, x;
  yield;
}

iterator Naturals(u: int) yields (n: nat)
  requires u < 25;  // just to have some precondition
  ensures false;  // never ends
{
  n := 0;
  while (true)
  {
    yield n;
    n := n + 1;
  }
}

method Main() {
  var m := new MyIter.MyIter(12);
  assert m.ys == m.xs == [];
  var a := m.x;
  if (a <= 13) {
    print "-- ", m.x, " --\n";
  }

  var mer := m.MoveNext();
  if (mer) {
    mer := m.MoveNext();
    mer := m.MoveNext();  // error
  }

  var n := new MyIntIter.MyIntIter();
  var patience := 10;
  while (patience != 0)
    invariant n.Valid() && fresh(n._new);
  {
    var more := n.MoveNext();
    if (!more) { break; }
    print n.x, ", ", n.y, "\n";
    patience := patience - 1;
  }

  var o := new Naturals.Naturals(18);
  var remaining := 100;
  while (remaining != 0)
    invariant o.Valid() && fresh(o._new);
  {
    var more := o.MoveNext();
    assert more;
    print o.n, " ";
    remaining := remaining - 1;
    if (remaining % 10 == 0) { print "\n"; }
  }
}

// -----------------------------------------------------------

class Cell {
  var data: int;
}

iterator IterA(c: Cell)
  requires c != null;
  modifies c;
{
  while (true) {
    c.data := *;
    yield;
  }
}

method TestIterA()
{
  var c := new Cell;
  var iter := new IterA.IterA(c);
  var tmp := c.data;
  var more := iter.MoveNext();
  assert tmp == c.data;  // error
}

// -----------------------------------------------------------

iterator IterB(c: Cell)
  requires c != null;
  modifies c;
  yield ensures c.data == old(c.data);
  ensures true;
  decreases c, c != null, c.data;
{
  assert _decreases0 == c;
  assert _decreases1 == (c != null);
  assert _decreases2 == c.data;  // error: c is not protected by the reads clause
  var tmp := c.data;
  if (*) { yield; }
  assert tmp == c.data;  // error: c is not protected by the reads clause
  c.data := *;
}

method TestIterB()
{
  var c := new Cell;
  var iter := new IterB.IterB(c);
  var tmp := c.data;
  var more := iter.MoveNext();
  if (more) {
    assert tmp == c.data;  // no prob
  } else {
    assert tmp == c.data;  // error: the postcondition says nothing about this
  }
}

// ------------------ yield statements, and_decreases variables ----------------------------------

iterator IterC(c: Cell)
  requires c != null;
  modifies c;
  reads c;
  yield ensures c.data == old(c.data);
  ensures true;
  decreases c, c, c.data;
{
  assert _decreases2 == c.data;  // this time, all is fine, because the iterator has an appropriate reads clause
  var tmp := c.data;
  if (*) { yield; }
  if (*) { yield; }
  assert tmp == c.data;  // this time, all is fine, because the iterator has an appropriate reads clause
  c.data := *;
}

method TestIterC()
{
  var c := new Cell;
  var iter := new IterC.IterC(c);
  var tmp := c.data;
  var more := iter.MoveNext();
  if (more) {
    assert tmp == c.data;  // no prob
  } else {
    assert tmp == c.data;  // error: the postcondition says nothing about this
  }

  iter := new IterC.IterC(c);
  c.data := 17;
  more := iter.MoveNext();  // error: iter.Valid() may not hold
}

// ------------------ allocations inside an iterator ------------------

iterator AllocationIterator(x: Cell)
{
  assert _new == {};
  var h := new Cell;
  assert _new == {h};

  SomeMethod();
  assert x !in _new;
  assert null !in _new;
  assert h in _new;

  ghost var saveNew := _new;
  var u, v := AnotherMethod();
  assert u in _new;
  if {
    case true =>  assert v in _new - saveNew ==> v != null && fresh(v);
    case true =>  assert !fresh(v) ==> v !in _new;
    case true =>  assert v in _new;  // error: it may be, but, then again, it may not be
  }
}

static method SomeMethod()
{
}

static method AnotherMethod() returns (u: Cell, v: Cell)
  ensures u != null && fresh(u);
{
  u := new Cell;
}

iterator DoleOutReferences(u: Cell) yields (r: Cell, c: Cell)
  yield ensures r != null && fresh(r) && r !in _new;
  yield ensures c != null && fresh(c);  // but we don't say whether it's in _new
  ensures false;  // goes forever
{
  var myCells: seq<Cell> := [];
  while (true)
    invariant forall z :: z in myCells ==> z in _new;
  {
    c := new Cell;
    r := new Cell;
    c.data, r.data := 12, 12;
    myCells := myCells + [c];
    _new := _new - {r};  // remove our interest in 'r'
    yield;
    if (*) {
      _new := _new + {c};  // fine, since 'c' is already in _new
      _new := _new + {u};  // error: this does not shrink the set
    } else if (*) {
      assert c.data == 12;  // still true, since 'c' is in _new
      assert c in _new;  // as is checked here as well
      assert r.data == 12;  // error: it may have changed 
    } else {
      parallel (z | z in myCells) {
        z.data := z.data + 1;  // we're allowed to modify these, because they are all in _new
      }
    }
  }
}

method ClientOfNewReferences()
{
  var m := new DoleOutReferences.DoleOutReferences(null);
  var i := 86;
  while (i != 0)
    invariant m.Valid() && fresh(m._new);
  {
    var more := m.MoveNext();
    assert more;  // follows from 'ensures' clause of the iterator
    if (*) {
      m.r.data := i;  // this change is allowed, because we own it
    } else {
      m.c.data := i;  // this change, by itself, is allowed
      assert m.Valid();  // error:  ... however, don't expect m.Valid() to survive the change to m.c.data
    }
    i := i - 1;
  }
}