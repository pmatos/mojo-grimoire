@fieldwise_init
struct S(Copyable):
    var x: Int

    def m(self) -> Int:
        var b: Bool = 5
        return self.x

def f():
    var c: Bool = 6
    print(c)

def main():
    f()
