def f(x: Int) -> Int:
    print("f", x)
    return x
def bump(mut x: Int) -> Int:
    x += 10
    return 3
def h(var q: P) -> Int:
    return q.x
@fieldwise_init
struct P(Copyable):
    var x: Int

def g(var q: P, k: Int) -> Int:
    return k
def main():
    var p = P(1)
    var xs: List[Int] = [1]
    print(List[Int](range(g(p^, xs[-1]), p.x)))
