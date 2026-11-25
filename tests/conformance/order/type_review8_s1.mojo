@fieldwise_init
struct S(ImplicitlyCopyable):
    var a: Int
    var b: Bool
    def __bool__(self) -> Bool:
        return self.b
    def __add__(self, o: S) -> S:
        return self

def g(x: Int) -> Int:
    return x

def main():
    var y = S(1, True)
    var z = (y or S(g([1, 2]), True)) + y
    print(z.a)
