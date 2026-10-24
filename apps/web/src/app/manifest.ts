import type {MetadataRoute} from "next";
export default function manifest():MetadataRoute.Manifest{return {name:"NyayaSetu Student Portal",short_name:"NyayaSetu",description:"Student grievance tracking and filing",start_url:"/student",display:"standalone",background_color:"#f6f8f7",theme_color:"#145b4a",icons:[{src:"/nyayasetu.svg",sizes:"any",type:"image/svg+xml",purpose:"maskable"}]}}
