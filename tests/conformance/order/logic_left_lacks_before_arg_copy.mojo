@fieldwise_init
struct A(Movable):
    var n: Int


def idA(var x: A) -> A:
    return x^


def main():
    var a = A(1)
    var r = a or idA(a)
