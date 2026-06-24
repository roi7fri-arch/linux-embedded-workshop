#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>


int main()
{
	//sleep(1);
	unsigned char buf[30];
	int i = 0;
	unsigned char ch;
	int id;
	int ret;
	int status;
	pid_t id_from_wait;
	printf("linux-course-user:/$");
	while((ch=getc(stdin)) != 0x0A)
	{
		buf[i] = ch;	
		//putc(ch, stdout);
		i++;
	}
	buf[i]='\0';
	id = fork();
	if(id == 0)	//son code
	{
		execv(buf, NULL);
	}
	id_from_wait = waitpid(id, &status, 0);
	printf("son return code is %d\n", WEXITSTATUS(status));
	printf("linux-course-user:/$");
	getc(stdin);
	while(1);
	return 0;
}
