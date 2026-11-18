struct L0(Movable):
    var p0: List[P0]
    var p1: List[P1]
    var p2: List[P2]
    var p3: List[P3]
    var p4: List[P4]
    var p5: List[P5]
    def __init__(out self):
        self.p0 = List[P0]()
        self.p1 = List[P1]()
        self.p2 = List[P2]()
        self.p3 = List[P3]()
        self.p4 = List[P4]()
        self.p5 = List[P5]()

struct L1(Movable):
    var p0: List[P0]
    var p1: List[P1]
    var p2: List[P2]
    var p3: List[P3]
    var p4: List[P4]
    var p5: List[P5]
    def __init__(out self):
        self.p0 = List[P0]()
        self.p1 = List[P1]()
        self.p2 = List[P2]()
        self.p3 = List[P3]()
        self.p4 = List[P4]()
        self.p5 = List[P5]()

struct L2(Movable):
    var p0: List[P0]
    var p1: List[P1]
    var p2: List[P2]
    var p3: List[P3]
    var p4: List[P4]
    var p5: List[P5]
    def __init__(out self):
        self.p0 = List[P0]()
        self.p1 = List[P1]()
        self.p2 = List[P2]()
        self.p3 = List[P3]()
        self.p4 = List[P4]()
        self.p5 = List[P5]()

struct L3(Movable):
    var p0: List[P0]
    var p1: List[P1]
    var p2: List[P2]
    var p3: List[P3]
    var p4: List[P4]
    var p5: List[P5]
    def __init__(out self):
        self.p0 = List[P0]()
        self.p1 = List[P1]()
        self.p2 = List[P2]()
        self.p3 = List[P3]()
        self.p4 = List[P4]()
        self.p5 = List[P5]()

struct L4(Movable):
    var p0: List[P0]
    var p1: List[P1]
    var p2: List[P2]
    var p3: List[P3]
    var p4: List[P4]
    var p5: List[P5]
    def __init__(out self):
        self.p0 = List[P0]()
        self.p1 = List[P1]()
        self.p2 = List[P2]()
        self.p3 = List[P3]()
        self.p4 = List[P4]()
        self.p5 = List[P5]()

struct L5(Movable):
    var p0: List[P0]
    var p1: List[P1]
    var p2: List[P2]
    var p3: List[P3]
    var p4: List[P4]
    var p5: List[P5]
    def __init__(out self):
        self.p0 = List[P0]()
        self.p1 = List[P1]()
        self.p2 = List[P2]()
        self.p3 = List[P3]()
        self.p4 = List[P4]()
        self.p5 = List[P5]()

struct P0(Movable):
    var l0: L0
    var l1: L1
    var l2: L2
    var l3: L3
    var l4: L4
    var l5: L5
    def __init__(out self):
        self.l0 = L0()
        self.l1 = L1()
        self.l2 = L2()
        self.l3 = L3()
        self.l4 = L4()
        self.l5 = L5()

struct P1(Movable):
    var l0: L0
    var l1: L1
    var l2: L2
    var l3: L3
    var l4: L4
    var l5: L5
    def __init__(out self):
        self.l0 = L0()
        self.l1 = L1()
        self.l2 = L2()
        self.l3 = L3()
        self.l4 = L4()
        self.l5 = L5()

struct P2(Movable):
    var l0: L0
    var l1: L1
    var l2: L2
    var l3: L3
    var l4: L4
    var l5: L5
    def __init__(out self):
        self.l0 = L0()
        self.l1 = L1()
        self.l2 = L2()
        self.l3 = L3()
        self.l4 = L4()
        self.l5 = L5()

struct P3(Movable):
    var l0: L0
    var l1: L1
    var l2: L2
    var l3: L3
    var l4: L4
    var l5: L5
    def __init__(out self):
        self.l0 = L0()
        self.l1 = L1()
        self.l2 = L2()
        self.l3 = L3()
        self.l4 = L4()
        self.l5 = L5()

struct P4(Movable):
    var l0: L0
    var l1: L1
    var l2: L2
    var l3: L3
    var l4: L4
    var l5: L5
    def __init__(out self):
        self.l0 = L0()
        self.l1 = L1()
        self.l2 = L2()
        self.l3 = L3()
        self.l4 = L4()
        self.l5 = L5()

struct P5(Movable):
    var l0: L0
    var l1: L1
    var l2: L2
    var l3: L3
    var l4: L4
    var l5: L5
    def __init__(out self):
        self.l0 = L0()
        self.l1 = L1()
        self.l2 = L2()
        self.l3 = L3()
        self.l4 = L4()
        self.l5 = L5()

def main():
    var a = L0()
    print(len(a.p0))
