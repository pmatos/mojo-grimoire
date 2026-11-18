def copy_out(mut xs: List[Int]) -> List[Int]:
    var ys = List[Int](xs^)
    xs.append(9)
    return ys^


def main():
    var src: List[Int] = [1, 2]
    var dst = List[Int](src^)
    print(dst, src)
    var got = copy_out(src)
    print(got, src)
