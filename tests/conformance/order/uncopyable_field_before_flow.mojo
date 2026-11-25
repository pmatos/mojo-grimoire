@fieldwise_init
struct R(Movable):
    var x: Int

@fieldwise_init
struct S(Copyable):
    var r: R

def main():
    var y: Int
    print(y)
