@fieldwise_init
struct S(Movable):
    var k: Int

@fieldwise_init
struct C(Movable):
    var k: Int
    def __getitem__(self, i: Int) -> Int:
        return self.k

def f(x: Int):
    pass

def main():
    var s = S(7)
    var c = C(1)
    var xs: List[Int] = [1]
    var d = 0
    var d: Int = xs
