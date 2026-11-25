def f() -> Int:
    print(2)

@fieldwise_init
struct S(Copyable):
    var x: Int

    def m(self) -> Int:
        print(1)

def main():
    print(f())
