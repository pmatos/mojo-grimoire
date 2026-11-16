@fieldwise_init
struct Cell(Movable):
    var n: Int


def grow(mut cs: List[Cell]) -> Cell:
    cs.append(Cell(0))
    return Cell(len(cs))


def main():
    var cs: List[Cell] = [Cell(1)]
    cs[0] = grow(cs)
    print(cs[0].n)
