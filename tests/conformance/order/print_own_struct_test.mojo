@fieldwise_init
struct S(ImplicitlyCopyable, Movable):
    var n: Int
    var f: Bool
    def __bool__(self) -> Bool:
        return self.f

@fieldwise_init
struct M(Movable):
    var n: Int
    def __bool__(self) -> Bool:
        return self.n > 0

@fieldwise_init
struct P(Movable):
    var n: Int

def bi(x: Int) -> Int:
    return x

def main():
    var x = M(1)
    var y = M(2)
    var p = P(1)
    print(p, [x or y])
