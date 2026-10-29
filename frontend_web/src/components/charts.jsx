const colors=['#203e64','#2a6b7b','#005a43'];
export function TrendChart({values,labels}) {
 const x=i=>42+i*92, y=v=>170-(v-88)*12;
 const points=values.map((v,i)=>`${x(i)},${y(v)}`).join(' ');
 return <div className="chart-wrap"><svg viewBox="0 0 550 210" role="img" aria-label={`Tren kehadiran: ${values.map(v=>v+' persen').join(', ')}`}>
 {[90,92,94,96,98,100].map(v=><g key={v}><line x1="40" x2="522" y1={y(v)} y2={y(v)} stroke="#e8edf7"/><text x="0" y={y(v)+4}>{v}%</text></g>)}
 <polygon points={`42,190 ${points} 502,190`} fill="#dfe9f3" opacity=".8"/><polyline points={points} fill="none" stroke={colors[0]} strokeWidth="2.5"/>
 {values.map((v,i)=><g key={i}><circle cx={x(i)} cy={y(v)} r="3.5" fill="white" stroke={colors[0]} strokeWidth="2"><title>{labels[i]}: {v}%</title></circle><text x={x(i)} y="207" textAnchor="middle">{labels[i]}</text></g>)}
 </svg></div>;
}
export function BarChart({series,labels,grouped=false}) {
 const max=grouped?8:100;
 return <div className="chart-wrap"><svg viewBox="0 0 550 210" role="img" aria-label={grouped?'Jumlah laporan per minggu dan tingkat kelas':'Persentase kehadiran per hari'}>
 {[0,1,2,3,4].map(n=><g key={n}><line x1="35" x2="530" y1={175-n*35} y2={175-n*35} stroke="#e8edf7" strokeDasharray="3 3"/><text x="0" y={179-n*35}>{grouped?n*2:n*25+(n===4?'%':'')}</text></g>)}
 {series.map((item,i)=>{const vals=grouped?item:[item];const center=70+i*(440/Math.max(1,series.length-1));return <g key={i}>{vals.map((v,j)=><rect key={j} x={center-(grouped?25:16)+j*18} y={175-v/max*140} width={grouped?14:32} height={v/max*140} rx="3" fill={colors[j%3]}><title>{labels[i]}: {v}{grouped?' laporan':'%'}</title></rect>)}<text x={center} y="202" textAnchor="middle">{labels[i]}</text></g>;})}
 </svg></div>;
}
export function Donut({segments,value,caption}) {
 const total=segments.reduce((s,n)=>s+n.value,0)||1;let offset=0;
 return <div className="donut"><svg viewBox="0 0 200 200" role="img" aria-label={segments.map(s=>`${s.label}: ${s.value}`).join(', ')}><circle cx="100" cy="100" r="75" fill="none" stroke="#edf1f8" strokeWidth="24"/>{segments.map(s=>{const length=s.value/total*471.239;const el=<circle key={s.label} cx="100" cy="100" r="75" fill="none" stroke={s.color} strokeWidth="24" strokeDasharray={`${length} ${471.239-length}`} strokeDashoffset={-offset} transform="rotate(-90 100 100)"/>;offset+=length;return el;})}<text x="100" y="98" textAnchor="middle" className="donut-value">{value}</text><text x="100" y="119" textAnchor="middle">{caption}</text></svg></div>;
}
export function Legend({items}) {return <div className="legend">{items.map(s=><div key={s.label}><span><i style={{background:s.color}}/>{s.label}</span><strong>{s.value}</strong></div>)}</div>;}
