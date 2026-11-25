struct S(ImplicitlyCopyable):
    var n: Int
    def __init__(out self, n: Int):
        self.n = n
    def __iadd__(mut self, o: Int):
        self.n += o
struct W(Copyable):
    var xs: Array[S, 2]
    def __init__(out self, var xs: Array[S, 2]):
        self.xs = xs^
def main():
    var b: Array[Int, 2] = [1, 2]
    var a: Array[W, 2] = [W([S(1), S(2)]), W([S(3), S(4)])]
    a[5].xs[b[-1]] += 1
