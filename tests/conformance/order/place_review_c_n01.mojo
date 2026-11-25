@fieldwise_init
struct R(Copyable, Movable):
    var k: Int

    def __getitem__(ref self, i: Int) -> ref [self] R:
        return self

def main():
    var r = R(1)
    r[zz].k = 1
