def copy_in(xs: List[Int]) -> Int:
    var ys = List[Int](xs^)
    return len(ys)


def main():
    var src: List[Int] = [1]
    print(copy_in(src))
