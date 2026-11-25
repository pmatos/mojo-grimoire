@fieldwise_init
struct Q(Movable):
    var x: Int

@fieldwise_init
struct P(Movable):
    var a: Q
    var b: Q

def f():
    var p = P(Q(1), Q(2))
    var q = p.a^
    print(q.x)

def g():
    var y: Int
    print(y)

def main():
    f()
    g()
