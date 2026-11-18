def pick(ref grid: List[List[Int]], ref row: List[Int]) -> ref [grid, row] List[Int]:
    return row


def main():
    var grid: List[List[Int]] = [[1], [2]]
    var row: List[Int] = [5, 6]
    grid[0] = List[Int](pick(grid, row))
    print(grid[0])
