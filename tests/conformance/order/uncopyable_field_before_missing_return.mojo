def f() -> Int:
    print(1)

@fieldwise_init
struct R(Movable):
    var x: Int

@fieldwise_init
struct S(Copyable):
    var r: R

def main():
    print(f())
