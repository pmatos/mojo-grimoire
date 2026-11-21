@fieldwise_init
struct S(Movable):
    var xs: List[Int]

    def same(self, other: S) -> Bool:
        return self.xs == other.xs

    def grow(mut self, read_only: List[Int]) -> Bool:
        self.xs.append(1)
        return self.xs == read_only


def main():
    var s = S([1])
    var t = S([1])
    print(s.same(t))
    print(s.grow([1, 1]))
