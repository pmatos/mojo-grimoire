def main():
    var src: List[Int] = [1, 2]
    ref first = src[0]
    var dst = List[Int](src^)
    print(first, dst)
