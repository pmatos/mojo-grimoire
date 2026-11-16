@fieldwise_init
struct Box(Movable):
    var xs: List[Int]

    def put(mut self, ys: List[Int]):
        self.xs = ys.copy()


def make() -> List[Int]:
    return [1, 2]


def size(xs: List[Int]) -> Int:
    return len(xs)


def main():
    var xs = make()
    xs = [3, 4, 5]
    var b = Box([1])
    b.xs = [9, 9]
    b.put([7])
    var xss: List[List[Int]] = [[1], [2, 3]]
    xss.append([4])
    print(len(xs), len(b.xs), size([1, 2, 3, 4]), len(xss), len(xss[1]))
