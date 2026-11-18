def main():
    var src: List[Int] = [1, 2]
    var dst = List[Int](src)
    dst.append(3)
    dst[0] = 7
    print(dst, src)
    var grid: List[List[Int]] = [[1], [2, 3]]
    var row = List[Int](grid[1])
    row.append(4)
    var rows = List[List[Int]](grid)
    rows[0].append(5)
    print(row, rows, grid)
