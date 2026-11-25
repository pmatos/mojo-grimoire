@fieldwise_init
struct S(Copyable):
    var x: Int

    def m(self):
        var a: Array[Int, 2] = [1, 2]
        print(a[3])

def f():
    var y: Int = [1, 2]
    print(y)

def main():
    S(1).m()
    f()
