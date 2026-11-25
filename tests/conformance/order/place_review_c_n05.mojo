@fieldwise_init
struct R(Copyable, Movable):
    var k: Int

    def __getitem__(ref self, i: Int) -> ref [self] R:
        return self

def main():
    var l: List[R] = [R(1)]
    l[0][zz].k = 1
