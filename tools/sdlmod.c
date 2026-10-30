/* sdlmod.c - render a MOD through SDL_mixer 1.2 as the Linux original plays it (Phase 6o: its
   panning). gcc -O2 tools/sdlmod.c -o /tmp/sdlmod $(sdl-config --cflags --libs) -lSDL_mixer
   SDL_AUDIODRIVER=disk SDL_DISKAUDIOFILE=/tmp/d.raw SDL_DISKAUDIODELAY=0 /tmp/sdlmod SONG.MOD out.raw SECONDS
   out.raw: 44100 Hz stereo S16LE (the original opens the mixer with these). */
#include <SDL/SDL.h>
#include <SDL/SDL_mixer.h>
#include <stdio.h>
#include <stdlib.h>
static FILE *out; static long want, got;
static void post(void *u, Uint8 *s, int n){ if(got<want){fwrite(s,1,n,out); got+=n;} }
int main(int c, char **v){
  SDL_Init(SDL_INIT_AUDIO);
  if(Mix_OpenAudio(44100, AUDIO_S16, 2, 4096)){printf("open: %s\n",Mix_GetError());return 1;}
  out=fopen(v[2],"wb"); want=(long)atoi(v[3])*44100*4;
  Mix_SetPostMix(post,0);
  Mix_Music *m=Mix_LoadMUS(v[1]); if(!m){printf("load: %s\n",Mix_GetError());return 1;}
  Mix_PlayMusic(m,0);
  while(got<want && Mix_PlayingMusic()) SDL_Delay(5);
  fclose(out); Mix_CloseAudio(); return 0;
}
