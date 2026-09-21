#define mm 0x98
#define lop_quote 0x0
#define lop_loc 0x1
#define lop_skip 0x2
#define lop_fixo 0x3
#define lop_fixr 0x4
#define lop_fixrx 0x5
#define lop_file 0x6
#define lop_line 0x7
#define lop_spec 0x8
#define lop_pre 0x9
#define lop_post 0xa
#define lop_stab 0xb
#define lop_end 0xc
#define err(m) {fprintf(stderr,"Error in tetra %d: %s!\n",count,m);continue;}
#define y buf[2]
#define z buf[3]
#define sym_length_max 1000
/*1:*/
#line 16 "mmotype.w"

#include <stdio.h> 
#include <stdlib.h> 
#include <time.h> 
#include <string.h> 
/*5:*/
#line 66 "mmotype.w"

#ifdef __STDC__
#define ARGS(list) list
#else
#line 70 "mmotype.w"
#define ARGS(list) ()
#endif
#line 72 "mmotype.w"

/*:5*/
#line 21 "mmotype.w"

/*7:*/
#line 94 "mmotype.w"

typedef unsigned char byte;
typedef unsigned int tetra;
typedef struct{tetra h,l;}octa;

/*:7*/
#line 22 "mmotype.w"

/*4:*/
#line 61 "mmotype.w"

int listing;
int verbose;
FILE*mmo_file;

/*:4*//*11:*/
#line 152 "mmotype.w"

int count;
int byte_count;
byte buf[4];
int yz;
tetra tet;

/*:11*//*16:*/
#line 208 "mmotype.w"

octa cur_loc;
int listed_file;
int cur_file;
int cur_line;
char*file_name[256];
octa tmp;

/*:16*//*29:*/
#line 442 "mmotype.w"

int stab_start;
char sym_buf[sym_length_max];

char*sym_ptr;
char equiv_buf[20];

/*:29*/
#line 23 "mmotype.w"

/*8:*/
#line 101 "mmotype.w"

octa incr ARGS((octa,int));
octa incr(o,delta)
octa o;
int delta;
{
register tetra t;
octa x;
if(delta>=0){
t= 0xffffffff-delta;
if(o.l<=t)x.l= o.l+delta,x.h= o.h;
else x.l= o.l-t-1,x.h= o.h+1;
}else{
t= -delta;
if(o.l>=t)x.l= o.l-t,x.h= o.h;
else x.l= o.l+(0xffffffff+delta)+1,x.h= o.h-1;
}
return x;
}

/*:8*//*9:*/
#line 126 "mmotype.w"

void read_tet ARGS((void));
void read_tet()
{
if(fread(buf,1,4,mmo_file)!=4){
fprintf(stderr,"Unexpected end of file after %d tetras!\n",count);

exit(-3);
}
yz= (buf[2]<<8)+buf[3];
tet= (((buf[0]<<8)+buf[1])<<16)+yz;
if(verbose)printf("  %08x\n",tet);
count++;
}

/*:9*//*10:*/
#line 141 "mmotype.w"

byte read_byte ARGS((void));
byte read_byte()
{
register byte b;
if(!byte_count)read_tet();
b= buf[byte_count];
byte_count= (byte_count+1)&3;
return b;
}

/*:10*//*26:*/
#line 385 "mmotype.w"

void print_stab ARGS((void));
void print_stab()
{
register int m= read_byte();
register int c;
register int j,k;
if(m&0x40)print_stab();
if(m&0x2f){
/*27:*/
#line 415 "mmotype.w"

if(m&0x80)j= read_byte();
else j= 0;
c= read_byte();
if(j)c= '?';

/*:27*/
#line 394 "mmotype.w"
;
*sym_ptr++= c;
if(sym_ptr==&sym_buf[sym_length_max]){
fprintf(stderr,"Oops, the symbol is too long!\n");exit(-7);

}
if(m&0xf)
/*28:*/
#line 421 "mmotype.w"

{
*sym_ptr= '\0';
j= m&0xf;
if(j==15)sprintf(equiv_buf,"$%03d",read_byte());
else if(j<=8){
strcpy(equiv_buf,"#");
for(;j> 0;j--)sprintf(equiv_buf+strlen(equiv_buf),"%02x",read_byte());
if(strcmp(equiv_buf,"#0000")==0)strcpy(equiv_buf,"?");
}else{
strncpy(equiv_buf,"#20000000000000",33-2*j);
equiv_buf[33-2*j]= '\0';
for(;j> 8;j--)sprintf(equiv_buf+strlen(equiv_buf),"%02x",read_byte());
}
for(j= k= read_byte();;k= read_byte(),j= (j<<7)+k)if(k>=128)break;

printf("    %s = %s (%d)\n",sym_buf+1,equiv_buf,j-128);
}

/*:28*/
#line 401 "mmotype.w"
;
if(m&0x20)print_stab();
sym_ptr--;
}
if(m&0x10)print_stab();
}

/*:26*/
#line 24 "mmotype.w"


int main(argc,argv)
int argc;char*argv[];
{
register int j,delta,postamble= 0;
register char*p;
/*2:*/
#line 40 "mmotype.w"

listing= 1,verbose= 0;
for(j= 1;j<argc-1&&argv[j][0]=='-'&&argv[j][2]=='\0';j++){
if(argv[j][1]=='s')listing= 0;
else if(argv[j][1]=='v')verbose= 1;
else break;
}
if(j!=argc-1){
fprintf(stderr,"Usage: %s [-s] [-v] mmofile\n",argv[0]);

exit(-1);
}

/*:2*/
#line 31 "mmotype.w"
;
/*3:*/
#line 53 "mmotype.w"

mmo_file= fopen(argv[argc-1],"rb");
if(!mmo_file){
fprintf(stderr,"Can't open file %s!\n",argv[argc-1]);

exit(-2);
}

/*:3*//*12:*/
#line 159 "mmotype.w"

count= byte_count= 0;

/*:12*//*17:*/
#line 216 "mmotype.w"

cur_loc.h= cur_loc.l= 0;
listed_file= cur_file= -1;
cur_line= 0;

/*:17*/
#line 32 "mmotype.w"
;
/*23:*/
#line 329 "mmotype.w"

read_tet();
if(buf[0]!=mm||buf[1]!=lop_pre){
fprintf(stderr,"Input is not an MMO file (first two bytes are wrong)!\n");

exit(-5);
}
if(y!=1)fprintf(stderr,
"Warning: I'm reading this file as version 1, not version %d!\n",y);

if(z> 0){
j= z;
read_tet();
if(listing){
time_t t= tet;
printf("File was created %s",asctime(localtime((time_t*)&t)));
}
for(j--;j> 0;j--){
read_tet();
if(listing)printf("Preamble data %08x\n",tet);
}
}

/*:23*/
#line 33 "mmotype.w"
;
do/*13:*/
#line 164 "mmotype.w"

{
read_tet();
loop:if(buf[0]==mm)switch(buf[1]){
case lop_quote:if(yz!=1)
err("YZ field of lop_quote should be 1");

read_tet();break;
/*18:*/
#line 228 "mmotype.w"

case lop_loc:if(z==2){
j= y;read_tet();cur_loc.h= (j<<24)+tet;
}else if(z==1)cur_loc.h= y<<24;
else err("Z field of lop_loc should be 1 or 2");

read_tet();cur_loc.l= tet;
continue;
case lop_skip:cur_loc= incr(cur_loc,yz);continue;

/*:18*//*19:*/
#line 242 "mmotype.w"

case lop_fixo:if(z==2){
j= y;read_tet();tmp.h= (j<<24)+tet;
}else if(z==1)tmp.h= y<<24;
else err("Z field of lop_fixo should be 1 or 2");

read_tet();tmp.l= tet;
if(listing)printf("%08x%08x: %08x%08x\n",tmp.h,tmp.l,cur_loc.h,cur_loc.l);
continue;
case lop_fixr:delta= yz;goto fixr;
case lop_fixrx:j= yz;if(j!=16&&j!=24)
err("YZ field of lop_fixrx should be 16 or 24");

read_tet();delta= tet;
if(delta&0xfe000000)err("increment of lop_fixrx is too large");

fixr:tmp= incr(cur_loc,-(delta>=0x1000000?(delta&0xffffff)-(1<<j):delta)<<2);
if(listing)printf("%08x%08x: %08x\n",tmp.h,tmp.l,delta);
continue;

/*:19*//*20:*/
#line 264 "mmotype.w"

case lop_file:if(file_name[y]){
for(j= z;j> 0;j--)read_tet();
cur_file= y;
if(z)err("Two file names with the same number");

}else{
if(!z)err("No name given for newly selected file");

file_name[y]= (char*)calloc(4*z+1,1);
if(!file_name[y]){
fprintf(stderr,"No room to store the file name!\n");exit(-4);

}
cur_file= y;
for(j= z,p= file_name[y];j> 0;j--,p+= 4){
read_tet();
*p= buf[0];*(p+1)= buf[1];*(p+2)= buf[2];*(p+3)= buf[3];
}
}
cur_line= 0;continue;
case lop_line:if(cur_file<0)err("No file was selected for lop_line");

cur_line= yz;continue;

/*:20*//*21:*/
#line 292 "mmotype.w"

case lop_spec:if(listing){
printf("Special data %d at loc %08x%08x",yz,cur_loc.h,cur_loc.l);
if(!cur_line)printf("\n");
else if(cur_file==listed_file)printf(" (line %d)\n",cur_line);
else{
printf(" (\"%s\", line %d)\n",file_name[cur_file],cur_line);
listed_file= cur_file;
}
}
while(1){
read_tet();
if(buf[0]==mm){
if(buf[1]!=lop_quote||yz!=1)goto loop;
read_tet();
}
if(listing)printf("                   %08x\n",tet);
}

/*:21*//*22:*/
#line 313 "mmotype.w"

case lop_pre:err("Can't have another preamble");

case lop_post:postamble= 1;
if(y)err("Y field of lop_post should be zero");

if(z<32)err("Z field of lop_post must be 32 or more");

continue;
case lop_stab:err("Symbol table must follow postamble");

case lop_end:err("Symbol table can't end before it begins");

/*:22*/
#line 172 "mmotype.w"

default:err("Unknown lopcode");

}
if(listing)/*15:*/
#line 190 "mmotype.w"

{
printf("%08x%08x: %08x",cur_loc.h,cur_loc.l,tet);
if(!cur_line)printf("\n");
else{
if(cur_loc.h&0xe0000000)printf("\n");
else{
if(cur_file==listed_file)printf(" (line %d)\n",cur_line);
else{
printf(" (\"%s\", line %d)\n",file_name[cur_file],cur_line);
listed_file= cur_file;
}
}
cur_line++;
}
cur_loc= incr(cur_loc,4);cur_loc.l&= -4;
}

/*:15*/
#line 176 "mmotype.w"
;
}

/*:13*/
#line 34 "mmotype.w"
while(!postamble);
/*24:*/
#line 352 "mmotype.w"

for(j= z;j<256;j++){
read_tet();tmp.h= tet;read_tet();
if(listing){
if(tmp.h||tet)printf("g%03d: %08x%08x\n",j,tmp.h,tet);
else printf("g%03d: 0\n",j);
}
}

/*:24*/
#line 35 "mmotype.w"
;
/*25:*/
#line 365 "mmotype.w"

read_tet();
if(buf[0]!=mm||buf[1]!=lop_stab){
fprintf(stderr,"Symbol table does not follow the postamble!\n");

exit(-6);
}
if(yz)fprintf(stderr,"YZ field of lop_stab should be zero!\n");

printf("Symbol table (beginning at tetra %d):\n",count);
stab_start= count;
sym_ptr= sym_buf;
print_stab();
/*30:*/
#line 449 "mmotype.w"

while(byte_count)
if(read_byte())fprintf(stderr,"Nonzero byte follows the symbol table!\n");

read_tet();
if(buf[0]!=mm||buf[1]!=lop_end)
fprintf(stderr,"The symbol table isn't followed by lop_end!\n");

else if(count!=stab_start+yz+1)
fprintf(stderr,"YZ field at lop_end should have been %d!\n",count-yz-1);

else{
if(verbose)printf("Symbol table ends at tetra %d.\n",count);
if(fread(buf,1,1,mmo_file))
fprintf(stderr,"Extra bytes follow the lop_end!\n");

}


/*:30*/
#line 378 "mmotype.w"
;

/*:25*/
#line 36 "mmotype.w"
;
return 0;
}

/*:1*/
