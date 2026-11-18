@fieldwise_init
struct C(Copyable):
    var k: Int


def main():
    var l: List[C] = [C(1)]
    var m = l^
    var u = l[0]^
    print(u.k, len(m))
