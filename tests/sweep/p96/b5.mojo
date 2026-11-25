def main():
    var y: Int
    print(y)

@fieldwise_init
struct S(Copyable):
    var x: Int

    def m(self):
        var a: Int
        print(a)
