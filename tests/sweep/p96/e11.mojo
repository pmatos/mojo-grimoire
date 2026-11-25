@fieldwise_init
struct S(Copyable):
    var x: Int

    def m(self):
        var a: Array[Int, 2] = [1, 2]
        print(a[3])

    def unused(self):
        var a: Array[Int, 2] = [1, 2]
        print(a[4])

def main():
    var s = S(1)
    s.m()
