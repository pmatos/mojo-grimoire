@fieldwise_init
struct P(Movable):
    var x: Int
def g(xs: Array[Int, 2]) -> Int:
    return len(xs)
def h(xs: List[Int]) -> Int:
    return len(xs)
def k(xs: List[Array[Int, 2]]) -> Int:
    return len(xs)
def main():
    print(g([1, 2, 3]))
