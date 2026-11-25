@fieldwise_init
struct R(Copyable, Movable):
    var id: Int


def show(k: Int) -> Int:
    print("eval", k)
    return k


def main():
    var rs: List[R] = [R(1), R(2)]
    rs[show(0)].id = show(5)
    print(rs[0].id, rs[1].id)
