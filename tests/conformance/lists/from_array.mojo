def main():
    var arr: Array[Int, 3] = [4, 5, 6]
    var xs = List[Int](arr)
    xs.append(7)
    print(xs, arr)
    var ys = List[Int]([8, 9])
    print(ys, len(List[Int]([1, 2, 3])))
