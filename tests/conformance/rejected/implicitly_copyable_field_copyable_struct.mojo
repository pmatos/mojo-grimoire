@fieldwise_init
struct C(Copyable):
    var x: Int

@fieldwise_init
struct S(ImplicitlyCopyable):
    var c: C


def main():
    print(1)
