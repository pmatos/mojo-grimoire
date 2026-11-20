def main():
    print(List[Int](range(3)))
    print(List[Int](range(2, 5)))
    print(List[Int](range(10, 0, -3)))
    print(List[Int](range(0, 10, 3)), List[Int](range(0, 9, 3)))
    print(List[Int](range(0, 10, 100)), List[Int](range(0, -10, -100)))
    var n = 4
    var xs = List[Int](range(n))
    xs.append(9)
    print(xs, len(xs))
