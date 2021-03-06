package org.example;

import java.util.ArrayList;
import java.util.List;

/**
 * 
 * create-date: 2020/5/23-20:17
 */
public class Allocator {

    private List<Object> list=new ArrayList<>();
    synchronized  boolean apply(Object from,Object to){
        if(list.contains(from)||list.contains(to)){
            return false;
        }
        list.add(from);
        list.add(to);
        return true;
    }

    synchronized void free(Object from,Object to){
        list.remove(from);
        list.remove(to);
    }


}
