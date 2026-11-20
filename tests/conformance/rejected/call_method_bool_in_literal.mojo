@fieldwise_init
struct C(Copyable):
    var n: Int

    def __call__(self, x: List[Int]) -> Bool:
        return True


def main():
    var len = C(1)
    var xs: List[Int] = [1]
    print(-[True, len(xs)])
