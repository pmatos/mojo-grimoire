@fieldwise_init
struct S(Copyable):
    var x: Int

    def m(self):
        var a: Int
        print(a)

def f():
    var y: Int
    print(y)

def main():
    S(1).m()
    f()
