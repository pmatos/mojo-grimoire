@fieldwise_init
struct P(Movable):
    var x: Int

def f(mut p: P):
    var q = p^
    print(q.x)

def g():
    var y: Int
    print(y)

def main():
    var p = P(1)
    f(p)
    g()
