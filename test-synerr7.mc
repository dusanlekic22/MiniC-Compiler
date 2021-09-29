//OPIS: sintaksna greska sa ugnjezdenim branchom
unsigned main() {
    unsigned a,b,c;
    a = 2u;
    b = 3u;
    c = 4u;
branch ( a ; 1u , 3u , 5u )
one -> a = a + 1u;
two -> 
branch ( a ; 1u , 3u , 5u )
one -> a = a + 1u;
two -> a = a + 3u;
three -> a = a + 5u;
other -> a = a - 3u;
end_branch;
three -> a = a + 5u;
other -> a = a - 3u;
end_branch
    return a;
}
