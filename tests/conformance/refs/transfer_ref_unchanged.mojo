@fieldwise_init
struct H(Movable):
    var l: List[Int]
    var k: Int

    def peek(ref self) -> Int:
        return self.k


def touch(ref x: List[Int]):
    print("touch", len(x))


def main():
    var h = H([1, 2], 3)
    ref e = h.l[0]
    touch(h^.l)
    print(h^.peek())
    print(e)
