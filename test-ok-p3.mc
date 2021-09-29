//OPIS: BRANCH iskaz
//RETURN: 5

unsigned main() {
    unsigned a,b,c;
    a = 2u;
    b = 3u;
    c = 4u;
branch ( a ; 1u , 2u , 5u )
one -> a = a + 1u;
two -> a = a + 3u;
three -> a = a + 5u;
other -> a = a - 3u;
end_branch
    return a;
}
