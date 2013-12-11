function aspect_freq_correct(data_buffer,opt_struct)
% ASPECT_FREQ_CORRECT(data_buffer)
% data_buffer is a large_array object with a data element and an
% input_headfile element
% relefvent info shoul dbe pulled from the input_headfile.
% this function is very experimental at current. It is largly taken from
% the aspect gre3d code from peterbenel given to jamescook


irep=1;
%
res=1;
noise_box=9;

zero_pad=2;
avr_mul=2;
noise_border=4;
signal_mul=3;
nrec=1;
remove_slice=opt_struct.remove_slice;
%% load  meta(header) info

if exist('data_buffer','var')
    recon_variables(1)=data_buffer.input_headfile.dim_X;
    recon_variables(2)=data_buffer.input_headfile.dim_Y;
    recon_variables(3)=data_buffer.input_headfile.dim_Z;
    recon_variables(4)=data_buffer.input_headfile.ne;
    recon_variables(5)=data_buffer.input_headfile.z_Aspect_DWEL_TIME;
    recon_variables(6)=data_buffer.input_headfile.te*1000;
    recon_variables(7)=0;
    recon_variables(8)=data_buffer.input_headfile.z_Aspect_ASIMMETRIA;
    fid=data_buffer.data;
else
    help aspect_freq_correct;
    error('DATA NOT SPECIFIED!');
    path = '/panoramaspace/A013405.work';
    recon_variables=load([path,'/recdata.dat']);
    dim_X=recon_variables(1);
    dim_Y=recon_variables(2);
    dim_Z=recon_variables(3);
    nfile=fopen([path,'/aspect_gre3d_FM_SP.tnt']);
    binary_header=fread(nfile,1056,'char');
    %%% load data
    fid=fread(nfile,dim_X*dim_Y*dim_Z*nrec*2,'float');
    fid=fid(1:2:end)+1i*fid(2:2:end);
    fclose(nfile);
    clear nfile binary_header;
end

dim_X=recon_variables(1);
dim_Y=recon_variables(2);
dim_Z=recon_variables(3);
Nex=recon_variables(4);


%% reshape
fid=permute(fid,[1,3,2,4,5,6]);
fid=reshape(fid, dim_X,dim_Z,dim_Y);


%% caluclate frequency correction
% pulls out the last slice of data to calculate frequency.
tsample=recon_variables(5)*1e-6;
te=recon_variables(6)*1e-6;
echo_ass=recon_variables(8);%50 in usual case
bw=1/tsample;
pix_bw=1/tsample/(dim_X*zero_pad);

fid_FM=squeeze(fid(:,dim_Z,:));
FM_mag=abs(fftshift(fft(fid_FM,dim_X*zero_pad,1),1));

[dummy,pos]=max(FM_mag);
freq_f=(pos-dim_X*zero_pad/2)*pix_bw;
gradf=diff(freq_f);
urf=bw*[0,cumsum((abs(gradf)>.9*bw))];
freq_f=freq_f+urf;
p=polyfit(0:1/(dim_Y-1):1,freq_f,4);
freq_drift=polyval(p,0:1/(dim_Y*dim_Z-1):1);
%   freq_drift=zeros(1,Npe*Npe2);

input_fid=fid;  % preserve input_fid for later.
fid=reshape(fid,dim_X,dim_Y*dim_Z); % put fid back into rays 
ns=fix(-dim_X/2*(1-echo_ass/100));
nf=ns+dim_X-1;
%% apply frequency correction
for i=1:dim_Y*dim_Z
    freq_cor=exp(2i*pi*freq_drift(i)*((ns:nf)*tsample+te));
    fid(:,i)=fid(:,i).*freq_cor';
end
fid=reshape(fid,dim_X,dim_Z,dim_Y);
if remove_slice
    fid(:,dim_Z,:)=[]; % delete last slice? why?(i've removed this
% for now)
end
largest_planar_dimension=max(dim_X,dim_Y);
zf=largest_planar_dimension-dim_Y;
zfi=floor(zf/2)+mod(zf,2);
fid2=zeros(largest_planar_dimension,dim_Z-remove_slice,largest_planar_dimension);
fid2(:,:,(zfi+1):zfi+dim_Y)=fid;

data_buffer.data=permute(fid2,[1,3,2,4,5,6]);

% % clear fid_feq_cor
% %
% img=fftshift(fftn(fftshift(fid2)),1);
% clear fid2
% img=permute(img,[1,3,2]);
% %reverse slice order
% img=img(:,:,end:-1:1);
% 
% magnitude_img=[];
% magnitude_img(:,:,:)=abs(squeeze(img(:,:,:)));
% %
% image1=magnitude_img(:,:,1:dim_Z-1);
% % clear magnitude_img img
% 
% 
% %I assume that image1 is the data file before normalization
% dimensions=size(image1);
% % largest_planar_dimension=max([dim_X dim_Y]);
% %read the file of existing image sum temp.dat
% % if irep>1
% %     nfile=fopen(path1,'r');
% %     exist_file=fread(nfile,'float');
% %     fclose(nfile)
% %     image_temp=reshape(exist_file,largest_planar_dimension,largest_planar_dimension,dim_Z-1);
% %     %
% %     image_sum=image1+image_temp;     %this is the sum including the current average
% % else
%     image_sum=image1;
% % end
% %
% % clear image_temp
% %
% %export the last frequency
% last_f(irep)=freq_f(dim_Y);
% new_freq=last_f(irep);
% ndata=[dim_X dim_Y dim_Z recon_variables(4) recon_variables(5) recon_variables(6) recon_variables(7) last_f(irep)];
% ndata=ndata';
% %
% filename = [path,'\last_freq.txt'];
% save(filename,'new_freq','-ascii');
% %save c:\NTNMR\last_freq.txt new_freq -ascii
% 
% %
% %save the latest current sum (unless we reached the the last average)
% % if irep<Nex
% %     nfile=fopen(path1,'w');
% %     fwrite(nfile,image_sum,'float');
% %     fclose(nfile)
% %     % if we have reached the last average
% % else
%     %
%     % norm = max(max(max(image_sum)));
%     norm = max(image_sum(:));
% %     voxels=dim_X*dim_Y*dim_Z;
%     morm=norm/4095;
%     magnitude_img = image_sum/morm;
%     sf=1/morm;
%     
%     clear image_sum
%     %
%     path1=[path,'/recdata.dat'];
%     nfile=fopen(path1,'a');
%     fprintf(nfile,'%d\n',sf);
%     fclose(nfile);
%     %
%     path2=[path,'/recdata_aspect_freqcor.raw'];
%     nfile=fopen(path2,'w');
%     magnitude_img=circshift(magnitude_img,[-16 64 0]);
%     fwrite(nfile,magnitude_img,'float');
% % end
% % exit


