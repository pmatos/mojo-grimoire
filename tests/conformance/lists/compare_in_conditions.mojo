def main():
    var xs: List[Int] = []
    var ys: List[Int] = [0, 1, 2]
    var i = 0
    while xs != ys:
        xs.append(i)
        i += 1
    if xs == ys and xs == [0, 1, 2]:
        print("same", i)
