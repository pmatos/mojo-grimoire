@fieldwise_init
struct copy_immutable_uninitialized_origin(Movable):
    var x: Int


def main():
    var p = copy_immutable_uninitialized_origin(1)
    print(p[0])
